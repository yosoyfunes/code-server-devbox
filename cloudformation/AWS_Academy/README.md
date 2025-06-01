## Deploy en Instancias de AWS Academy con el Role LabInstanceProfile

Para desplegar Cloudformation, usarmos AWS CLI con el siguiente comando o usar la consola de AWS CloudFormation.

```bash
aws cloudformation create-stack \
 --stack-name code-server-stack \
 --template-body file://code-server-stack.yaml \
 --capabilities CAPABILITY_NAMED_IAM
```