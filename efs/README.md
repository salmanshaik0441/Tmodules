## EFS Module
This is to allow the creation of an EFS and for example create multiple EKS clusters using the same EFS

---
**Usage**
```  
module "eks_efs_file_system" {  
  source = "git::ssh://git@git.bitbucket.orbit.prod.vodacom.co.za/vtm/efs.git"  
  efs_encrypted = var.efs_encrypted  
  kms_efs_key_arn = var.kms_efs_key_arn  
  efs_name_prefix = ""  
} 
```