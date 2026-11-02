# Segurança

Reporte vulnerabilidades pela opção **Security → Advisories → Report a vulnerability** do repositório GitHub, usando private vulnerability reporting. Não abra uma issue pública com detalhes exploráveis, tokens, state ou endereços reais. Se o formulário privado ainda não estiver habilitado, aguarde sua habilitação antes de enviar detalhes sensíveis.

Inclua versão do código, impacto e reprodução mínima sem segredos. O projeto não oferece prazo de resposta ou auditoria contratada.

A fronteira é uma VPS pessoal com contas sem sudo e acesso por overlay. Root, administrador e kernel são confiáveis. Contas de agentes não são sandbox para código hostil; egress por IP não garante isolamento de dados.

Nunca versione tfvars reais, state, planos, inventário real, chaves ou arquivos de ambiente. Consulte a [política do repositório](setup/docs/REPO-SAFETY.md).
