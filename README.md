# personal-gen-ai

You will need to install **aws-cli** and **terraform >= 1.5.7**

1. Edit the *terraform.tfvars* file to select your instance region and add your SSH key name
2. Enter the following commands to provision your personal Gen AI using open WebUI and Ollama
  > terraform init \
  > terraform plan -out plan.zip \
  > terraform apply plan.zip
=> a public IP address will be displayed: public_ip = WW.XX.YY.ZZ

3. Start to use your open WebUI with your browser at the following URL : http//WW.XX.YY.ZZ:3000
4. To deprovision your instance, enter the following command:
> terraform plan -destroy -out plan-destroy.zip
> terraform apply plan-destroy.zip
