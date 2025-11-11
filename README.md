# personal-gen-ai

You will need to install **aws-cli** and **terraform >= 1.5.7**

1. Edit the *terraform.tfvars* file to select your instance region and add your SSH key name
2. Enter the following commands to provision your personal Gen AI using open WebUI and Ollama
```
> terraform init
> terraform plan -out plan.zip
> terraform apply plan.zip
```
=> a public IP address will be displayed: ec2_public_ip = WW.XX.YY.ZZ
=> and the https_url = https://ec2_public_ip

3. Start to use your open WebUI with your browser at the following URL : https://ec2_public_ip
4. To deprovision your instance, enter the following command:
```
> terraform plan -destroy -out plan-destroy.zip
> terraform apply plan-destroy.zip
```
