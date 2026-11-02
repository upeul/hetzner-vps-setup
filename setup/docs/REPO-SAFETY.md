# Segurança de arquivos

Os exemplos são públicos. Não versione tokens, chaves, inventário real, tfvars, state ou planos. Use prompt protegido para o token Hetzner e remova a variável após o apply. O state contém dados sensíveis mesmo quando uma variável é marcada como sensitive.

Execute `bash setup/scripts/validate-repo-safety.sh` e gitleaks antes de publicar. Ausência de alertas não comprova ausência de segredos. Revise também nomes, comentários e histórico. Em caso de exposição revogue o segredo antes de tratar o histórico.
