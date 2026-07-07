region        = "eu-west-3"    # Change to the region you want to use
instance_type = "g4dn.2xlarge" # enough powerfull instance to run LLama4 => quotas request needed
volume_size   = 300            # 300 Go to be able to download large models
key_name      = "genAI"        # Replace with the name of your SSH key
instance_name = "gpu-deep-learning"
ollama_model  = "" # ex: "llama3.2" pour pré-télécharger un modèle au boot (vide = via l'UI)

