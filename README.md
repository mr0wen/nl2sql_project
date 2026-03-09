# 🤖 NL2SQL Assistant: Natural Language to SQL

Este é um projeto desenvolvido estritamente para **fins de estudos e pesquisa acadêmica**. Ele demonstra a implementação de uma arquitetura segura de integração entre Inteligência Artificial Generativa (LLMs) e bancos de dados relacionais, permitindo a consulta de dados estruturados através de linguagem natural.

## 🎯 Objetivo

O assistente atua como uma interface inteligente de banco de dados. O usuário insere uma pergunta em linguagem comum (ex: _"Quais são os 3 filmes com maior bilheteria da Marvel?"_, _"Liste os top 5 filmes de maior bilheteria que tenham a participação do ator Christian Bale."_), o sistema traduz essa intenção para uma query SQL otimizada usando o modelo **Google Gemini 2.5 Flash**, executa a consulta de forma segura e devolve os dados em uma tabela dinâmica.

## 🚀 Fases de Implementação (Evolução da Arquitetura)

O projeto foi estruturado para demonstrar e comparar a capacidade de raciocínio lógico (NLP) do modelo de IA em diferentes complexidades de banco de dados. A interface possui um botão para alternar os motores em tempo real:

- **Fase 1 (Tabela Única / Flat):** Arquitetura baseada em uma única tabela (`movies`). Ideal para demonstrar filtros diretos (`WHERE`, `ORDER BY`, `LIMIT`) e validação da API base.
- **Fase 2 (Banco Relacional / 3FN):** O sistema evolui para uma estrutura normalizada com tabelas independentes em português (`filmes`, `atores`, `diretores`, `generos`, etc.). Esta fase funciona como um teste de estresse para a IA, exigindo compreensão de chaves estrangeiras (Foreign Keys) e a construção de múltiplos `JOINS` sem ambiguidades.

## 🛠️ Tecnologias e Arquitetura

- **Frontend:** React 18, Vite, TypeScript, TailwindCSS v4, Lucide Icons.
- **Backend:** Ruby on Rails 8 (Modo API).
- **Banco de Dados:** PostgreSQL 16.
- **Inteligência Artificial:** Google Gemini API (Modelo `gemini-2.5-flash`).
- **Infraestrutura:** Docker & Docker Compose.
- **Web Scraping:** Nokogiri (Ruby) com algoritmo de mapeamento matricial 2D para extração de tabelas HTML complexas.

## 🔒 Arquitetura de Segurança (Defesa em Profundidade)

Para garantir que a integração com o LLM não crie vulnerabilidades no banco de dados (como _Prompt Injection_ ou _Query Stacking_), o motor implementa um modelo de **Defesa em Duas Camadas**:

1. **Camada de Sanitização (Motor de IA):** O `GeminiSqlService` fornece um contexto estrito (via _allowlist_ de tabelas) e proíbe a IA de gerar terminadores de instrução (`:`) que poderiam abrir brechas. Uma limpeza por código (`.chomp`) é feita antes do tráfego interno.
2. **Camada de Validação / WAF (Executor SQL):** O `SqlExecutionService` age como um "firewall" interno que não confia na IA. Ele:
   - Bloqueia qualquer instrução que não comece com `SELECT`.
   - Proíbe palavras reservadas perigosas (`DROP`, `DELETE`, `UPDATE`, `INSERT`, etc).
   - Impede ataques de _Stacking_ abortando a execução se identificar múltiplos comandos na mesma requisição.

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

4.  **Configuração do Banco de Dados:**

    ```Bash
    docker compose exec backend rails db:prepare
    ```

5.  **Importação dos Dados do IMDB (Fase 2):**
    Rode a task de ingestão de dados para popular as tabelas relacionais a partir dos arquivos .sql:

    ```Bash
    docker compose exec backend rails imdb:import_relational
    ```

6.  **Acesso à Aplicação:**

    Frontend: Acesse http://localhost:5173
    Backend (API): O Rails estará rodando em http://localhost:3000.

## 📝 Licença

Distribuído sob a licença MIT. Este é um projeto de código aberto voltado para a comunidade educacional. Consulte o arquivo LICENSE para mais informações.

Aviso de Isenção: Este software foi criado para fins experimentais e acadêmicos. Não execute consultas SQL geradas por IA dinamicamente em bancos de dados de produção sem camadas robustas de controle de acesso.
