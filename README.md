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


<br> <br>
<h3> STEP-BY-STEP flow </h3>
<b> This is how each Terraform resource works in the overall system. </b>

Start point: A public user opens a browser and requests http://my-app.example.com/
<br> <br>
1. DNS (optional step)
Browser prepares an HTTP request for the ALB’s public IP(s).
Client DNS lookup returns the ALB’s public DNS name (from Route53 or external DNS).


2. Client → Internet → Internet Gateway (IGW)
The Internet Gateway simply acts as the VPC’s public entry/exit point.
The IG is the VPC’s internet door — it lets traffic for your public IPs (like ALB or NAT) enter the VPC and lets responses go back out, but it does nothing else: no security, no filtering, no NAT logic, and no load balancing — it just passes packets in and out.


3. IGW → ALB (Application Load Balancer) node in a public subnet
After the packet passes through the IGW, it is delivered to an ALB node running inside one of your public subnets
Before the ALB even sees the request, the alb_sg security group is checked:
Ingress rule: 0.0.0.0/0 → TCP:80 ✅ (This allows any internet client to open a connection to the ALB.)
Because security group's are stateful, return traffic is automatically allowed.
open egress rule (0.0.0.0/0) simply lets the ALB connect to anything new (like targets or health checks), not for responses.
flow:

Client → IGW → ALB public node → alb_sg allows port 80 → TCP session established → request ready for listener routing.


4. ALB Listener receives the request
Once the TCP connection is established with the ALB node, the raw network traffic is handed to the ALB Listener (aws_lb_listener), which is the component that actually understands HTTP requests and decides where they should go.
1. Listens on port 80
The listener is bound to the ALB on TCP:80.
Any HTTP request reaching the ALB is delivered directly to this listener.
2. Consults the Target Group
The listener does not pick instances directly.
It asks the Target Group (app_tg):
“Which targets are registered AND currently healthy?”


5. Target Group health & selection
Once the listener forwards traffic to app_tg (aws_lb_target_group), the entire decision of who actually receives the request is controlled by the Target Group’s health system.
1. The target group holds private IPs of EC2 instances that your ASG registers automatically.(These instances live in private subnets — no public IPs.)
2. TG Continuously runs health checks, and The response MUST be: Status = 200
(Any timeout, connection failure, or wrong status = unhealthy.)
3. Only healthy instances are eligible to receive traffic. unhealthy instances are removed from load-balancing rotation. The listener stops sending requests to it completely.
When it recovers: It passes checks again → re-enters rotation automatically.
4. For each client request:
Listener requests a healthy target list from app_tg,
app_tg chooses one instance (round-robin by default),



6. ALB opens a new connection → private EC2 instance
Once the Target Group selects a healthy EC2 instance, the ALB performs its real job: it becomes a reverse proxy between the internet client and your private server.
1. The original client-to-ALB TCP connection stays open.Separately, the ALB node creates its own new TCP connection: 
Source: ALB node ENI (public subnet)
Destination: EC2 private IP :80
- This traffic is now 100% private
2. Security Group evaluation (the real gatekeeper)
The incoming packet hits the instance’s app_sg.
Rule: 
allow inbound TCP 80 from source SG = alb_sg
This means:
The packet is accepted ONLY if the source belongs to the ALB’s security group. Any other source — even from inside the VPC — is blocked.

(Q: Why SG reference is better than CIDR??
- ALB IP addresses change constantly. 
- Using CIDR rules like 10.0.0.0/8 would: Allow anything in the VPC to hit your app(unsafe).
- Using: security_groups = [alb_sg.id]
means:
- ONLY the ALB is trusted
- Nothing else can directly reach your app, zero dependency on changing IP ranges.


7. EC2 receives request and nginx responds
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


8. ALB → Client (response)
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




Full end-to-end round-trip example: 
Client → IGW → Public Subnet (ALB) → Listener → Target Group → EC2 Private Subnet (nginx) → Response → ALB → IGW →
Client

The client requests the website or app hosted on EC2 instances in private subnets. Using this architecture, the client can access the app without ever exposing the EC2 private IPs publicly, because the ALB handles all public traffic, and stateful security groups ensure only allowed connections pass while responses flow back automatically.
