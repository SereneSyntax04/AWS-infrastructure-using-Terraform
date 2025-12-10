<h1 align="center"> Production-Ready AWS Infrastructure using Terraform </h1>

<h4>About this Repository:</h4>
<b>1.Purpose of README: </b> <br>
This README is intended only to understand the runtime flow of the architecture, showing how a client request travels through the AWS infrastructure and how each service behaves in the process. It explains the traffic path, security group behavior, and subnet roles.

<b>2.Terraform Code: </b> <br>
The Terraform code in this repository provisions the entire architecture. All necessary commands to deploy the infrastructure are included. After running terraform apply, the architecture can be tested locally using Docker + LocalStack, which mimics AWS services defined in providers.tf. This allows you to verify the end-to-end request flow before deploying to a production-level AWS environment. You can follow the steps to create the VPC, subnets, ALB, EC2 instances, Target Groups, security groups, and NAT Gateway in the local environment.

---

<br>
<h1 align="center">		Production-Ready AWS Infrastructure using Terraform		 </h1>

<h2>Task: Write Terraform code to allow users to access a website hosted on EC2 instances in private subnets. </h2>

> Refer to the given architecture to understand the traffic flow and the AWS services involved (e.g., ALB, security groups, NAT Gateway, public/private subnets).

<p align="center">
  <img src="" alt="🏗️ FULL ARCHITECTURE DIAGRAM " width="400"/>
</p>


<h3> 🌍 CORE IDEA </h3>

I built a secure AWS application infrastructure where:
- Users access the app via a public Application Load Balancer
- Backend servers run on private EC2 inside an Auto Scaling Group
- Private servers access the internet outbound via a NAT gateway
- No server is publicly accessible directly

---

<br>
<h3> STEP-BY-STEP flow </h3>

<b> This is how each Terraform resource works in the overall system. </b>

**Start point:** A public user opens a browser and requests **`http://my-app.example.com/`** 
<br>

<h2> 1. DNS (optional step) </h2> 
Browser prepares an HTTP request for the ALB’s public IP(s). 

Client DNS lookup returns the ALB’s public DNS name (from **Route53** or external DNS).




<h2> 2. Client → Internet → Internet Gateway (IGW) </h2>
The Internet Gateway simply acts as the VPC’s public entry/exit point.  

**The IGW is the VPC’s internet door** — it lets traffic for your public IPs (like ALB or NAT) enter the VPC and lets responses go back out, but it does nothing else: no security, no filtering, no NAT logic, and no load balancing — it just passes packets in and out.




<h2> 3. IGW → ALB (Application Load Balancer) node in a public subnet </h2>

After the packet passes through the **IGW**, it is delivered to **an ALB node running inside one of your public subnets.**  <br>
Before the ALB even sees the request, the **ALB security group (`alb_sg`) is evaluated:** 
- **Ingress rule**: `0.0.0.0/0 → TCP:80` ✅ (This allows any internet client to open a connection to the ALB.)
(Security Groups are **stateful**, so once inbound traffic is allowed, **return traffic is automatically permitted** —
 no explicit egress rule is required for responses.)

- open **egress rule** `(0.0.0.0/0)` simply lets the ALB connect to anything new (like targets or health checks), not for responses.
  
**flow:**
> Client → IGW → ALB public node → alb_sg allows port 80 → TCP session established → request ready for listener routing.




<h2> 4. ALB Listener receives the request </h2>

Once the TCP connection is established with the ALB node, the raw network traffic is handed to the  **ALB Listener (`aws_lb_listener`)** , which is the component that actually understands HTTP requests and decides where they should go.

<b> 1. Listens on port 80 </b>
- The listener is bound to the ALB on **TCP:80**.
- Any HTTP request reaching the ALB is delivered directly to this listener.

<b> 2. Consults the Target Group </b>
- The listener does  **not** select EC2 instances directly.
- Instead, it queries the **Target Group (`app_tg`):** <br>
“Which targets are registered AND currently healthy?”




<h2> 5. Target Group health & selection </h2>

Once the listener forwards traffic to **`app_tg` (`aws_lb_target_group`)**, the responsibility for choosing **which EC2 instance actually receives the request** is handled entirely by the **Target Group’s health and routing system**.

<b>How it works</b>
1.  **Registered targets**
   - The target group holds **private IPs of EC2 instances** that your **Auto Scaling Group (ASG)** registers automatically.
   - These instances live in **private subnets** and **do not have public IPs**.

2. **Continuous health checks**
   - The target group continuously sends health probes to each instance.
   - A target is considered healthy only if the response is:
     ```
     HTTP 200
     ```
   - Any of the following marks a target **unhealthy**:
     - Timeout / no response
     - Connection failure
     - Wrong HTTP status code

3. **Traffic eligibility**
   - Only **healthy** instances are eligible to receive traffic.
   - **Unhealthy** instances are **removed from the load-balancing rotation** — the listener completely stops routing requests to them.
   - When an instance recovers:
     ```
     Passes health checks → Marked healthy → Automatically re-enters rotation
     ```

4. **Request distribution**
   
   For every incoming client request: <br>
   Listener requests healthy targets from app_tg → app_tg selects one instance (round-robin by default) → traffic forwarded to selected EC2 target




<h2> 6. ALB opens a new connection → private EC2 instance </h2>

Once the Target Group selects a healthy EC2 instance, the ALB performs its real job — it acts as a **reverse proxy** between the internet client and your private server.

<b> 1. Dual TCP connections: </b> 
- The original **client → ALB** TCP connection remains open.
- Separately, the ALB creates a **new outbound TCP connection** to the selected target:
```
Source: ALB node ENI (public subnet)
Destination: EC2 private IP :80
```
This traffic is now 100% private
  
<b> 2. Security Group evaluation (the real gatekeeper) </b> 

The inbound packet reaches the EC2 instance and hits the **application security group (`app_sg`)**.

**Inbound rule**
- Allow **TCP:80**
- Source = **Security Group reference → `alb_sg`**

This means:

- ✅ Traffic is accepted **ONLY if** the source belongs to the **ALB’s security group**
- ❌ Any other source — even from inside the VPC — is blocked
  
<h3> Q: Why SG reference is better than CIDR?? </h3>

**Problem with CIDR:**
- ALB IP addresses change constantly.
- Using CIDR rules like `10.0.0.0/8` would:
  - Allow **anything inside the VPC** to access your app
  - Create a large **blast radius** (unsafe)

**Correct approach:**
```hcl
security_groups = [alb_sg.id]
```
- **ONLY the ALB is trusted**
- Nothing else can directly reach your app, zero dependency on changing IP ranges.




<h2> 7. EC2 receives request and nginx responds </h2>
Once the ALB’s forwarded request reaches the private EC2 instance, control fully moves to your application layer.
What happens on the instance:
1. nginx is already running: Installed and started by your user_data at boot.
2. The HTTP request arrives from the ALB’s private-side TCP connection:
Source: ALB ENI
Destination: EC2 private IP :80
app_sg has already allowed the inbound connection because the source SG = alb_sg.
3. nginx processes the request, Serves the default page or your app logic and Sends back: HTTP/1.1 200 OK
The packet goes out through the same TCP session that the ALB opened.
Because SGs are stateful:
The outgoing response from EC2 → ALB is automatically allowed.
No explicit egress allow rule is required for reply packets.




<h2> 8. ALB → Client (response) </h2>
Once the ALB receives the HTTP 200 response from the EC2 backend, it finishes its proxy role and sends that response straight back to the user over the same already-open TCP connection that was established between the client and the ALB at the start.
technically:
1. ALB gets the backend response
- The response arrives on the private ALB→EC2 TCP connection.
- ALB reads the HTTP payload (headers + body).
2. ALB forwards to the client
- No new connection is created to the client.
- The existing session is reused.
Network path:
ALB node → IGW → AWS edge network → Internet → Client
3. Client receives :  Browser gets- HTTP/1.1 200 OK, Renders the page.

Important realities at this step
✅ Client never connects to EC2 directly
✅ EC2 IP is never exposed publicly
✅ ALB remains the single public entry/exit point
✅ Both sides use stable, stateful TCP sessions:

Client ↔ ALB
ALB ↔ EC2


---

<h3> Full end-to-end round-trip example: </h3>
Client → IGW → Public Subnet (ALB) → Listener → Target Group → EC2 Private Subnet (nginx) → Response → ALB → IGW →
Client

---

<br>
<h2> The client requests the website or app hosted on EC2 instances in private subnets. Using this architecture, the client can access the app without ever exposing the EC2 private IPs publicly, because the ALB handles all public traffic, and stateful security groups ensure only allowed connections pass while responses flow back automatically. <h2> 
