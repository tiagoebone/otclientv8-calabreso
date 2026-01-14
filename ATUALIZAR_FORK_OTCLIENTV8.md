# Atualizando o fork do otclientv8 (Calabreso)

Este repositório é um fork do projeto original:
https://github.com/OTAcademy/otclientv8

O repositório original está configurado como **upstream**  
O repositório Calabreso está configurado como **origin**

---

## Verificar repositórios remotos

```bash
git remote -v
```

Esperado:
- `origin` → https://github.com/tiagoebone/otclientv8-calabreso
- `upstream` → https://github.com/OTAcademy/otclientv8

---

## Buscar atualizações do repositório original

Baixa as mudanças do projeto original sem alterar teu código:

```bash
git fetch upstream
```

---

## Atualizar o branch main com o upstream

```bash
git checkout main
git merge upstream/main
git push origin main
```

Se não houver conflitos, o fork será atualizado normalmente

---

## Resolver conflitos (se ocorrerem)

1. Edite os arquivos marcados em conflito  
2. Após resolver:

```bash
git add .
git commit
git push
```

---

## Fluxo recomendado de trabalho

- `main` → espelha o projeto original
- branches próprias → alterações do Calabreso

Criar uma branch para modificações:

```bash
git checkout -b calabreso-changes
```

---

## Atualizar tua branch após atualizar o main

```bash
git checkout calabreso-changes
git merge main
```

---

## Boas práticas

- Nunca altere diretamente o `upstream`
- Sempre atualize o `main` antes de começar novas mudanças
- Faça commits pequenos e objetivos
- Resolva conflitos no `main` antes de seguir trabalhando
