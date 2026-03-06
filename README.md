# 🤖 NL2SQL Assistant: Natural Language to SQL

Este é um projeto desenvolvido estritamente para **fins de estudos e pesquisa acadêmica**. Ele demonstra a implementação de uma arquitetura segura de integração entre Inteligência Artificial Generativa (LLMs) e bancos de dados relacionais, permitindo a consulta de dados estruturados através de linguagem natural.

## 🎯 Objetivo

O assistente atua como uma interface inteligente de banco de dados. O usuário insere uma pergunta em linguagem comum (ex: _"Quais são os 3 filmes com maior bilheteria da Marvel?"_), o sistema traduz essa intenção para uma query SQL otimizada usando o modelo **Google Gemini 2.5 Flash**, executa a consulta de forma segura e devolve os dados em uma tabela dinâmica.

## 🛠️ Tecnologias e Arquitetura

- **Frontend:** React 18, Vite, TypeScript, TailwindCSS v4, Lucide Icons.
- **Backend:** Ruby on Rails 8 (Modo API).
- **Banco de Dados:** PostgreSQL 16.
- **Inteligência Artificial:** Google Gemini API (Modelo `gemini-2.5-flash`).
- **Infraestrutura:** Docker & Docker Compose.
- **Web Scraping:** Nokogiri (Ruby) com algoritmo de mapeamento matricial 2D para extração de tabelas HTML complexas.

## 🔒 Camada de Segurança (Prevenção contra Prompt Injection)

Executar SQL gerado por IA apresenta riscos severos. Este projeto implementa as seguintes travas a nível de aplicação (`SqlExecutionService`):

1.  **Enforcement de Leitura:** Apenas instruções que iniciam com `SELECT` são processadas.
2.  **Anti-Mutation:** Bloqueio via Regex de palavras-chave destrutivas (`DROP`, `DELETE`, `UPDATE`, `INSERT`, `ALTER`, etc.).
3.  **Anti-Stacking:** Bloqueio do caractere de terminação (`;`) para impedir o empilhamento de comandos maliciosos caso a IA sofra um bypass de prompt.

## 🚀 Como Executar o Projeto Localmente

### Pré-requisitos

- Docker e Docker Compose instalados na sua máquina.
- Uma chave de API válida do Google AI Studio.

### Passo a Passo

1.  **Clone o repositório:**

    ```bash
    git clone (https://github.com/mr0wen/nl2sql_project.git)
    cd nl2sql_project
    ```

2.  **Configure a variável de ambiente:**
    Crie um arquivo .env dentro da pasta backend/ e adicione a sua chave do Gemini:

    ```bash
    GEMINI_API_KEY=
    ```

3.  **Inicie a infraestrutura com o Docker Compose:**

    ```Bash
    docker compose up -d --build
    ```

    Prepare o Banco de Dados:
    Execute os comandos abaixo para criar o banco, rodar as migrations e executar o script de seed (que fará o web scraping para popular a base com filmes de super-heróis):

    ```Bash
    docker compose exec backend rails db:create
    docker compose exec backend rails db:migrate
    docker compose exec backend rails db:seed
    ```

    Acesse a Aplicação:
    Abra o seu navegador e acesse: http://localhost:5173

## 📝 Licença

Distribuído sob a licença MIT. Este é um projeto de código aberto voltado para a comunidade educacional. Consulte o arquivo LICENSE para mais informações.

Aviso de Isenção: Este software foi criado para fins experimentais e acadêmicos. Não execute consultas SQL geradas por IA dinamicamente em bancos de dados de produção sem camadas robustas de controle de acesso.
