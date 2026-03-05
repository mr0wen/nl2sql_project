module Api
  module V1
    # Controller responsável por receber perguntas em linguagem natural
    # e retornar os resultados da consulta ao banco de dados.
    #
    # Fluxo geral da requisição:
    #
    # 1. Recebe pergunta do usuário
    # 2. Envia a pergunta para o serviço que gera SQL via LLM
    # 3. Valida e executa o SQL gerado com regras de segurança
    # 4. Retorna os dados resultantes
    #
    # Esse controller funciona como a camada de orquestração entre:
    # - GeminiSqlService (geração de SQL)
    # - SqlExecutionService (validação e execução)
    class QueriesController < ApplicationController
      def create
        # Captura a pergunta enviada no body da requisição
        question = params[:question]

        # Validação básica para evitar chamadas desnecessárias à API do LLM
        # caso o usuário envie uma pergunta vazia
        if question.blank?
          return render json: { error: "A pergunta não pode estar vazia." }, status: :unprocessable_entity
        end

        # 1. Solicita a tradução da linguagem natural para SQL ao Gemini
        #
        # Este serviço utiliza o schema do banco como contexto e instrui
        # o modelo a gerar apenas uma consulta SQL válida.
        generated_sql = GeminiSqlService.new(question).call

        # 2. Valida e executa o SQL de forma segura contra o PostgreSQL
        #
        # O SqlExecutionService aplica várias proteções:
        # - Permite apenas consultas SELECT
        # - Bloqueia múltiplas instruções SQL
        # - Bloqueia palavras-chave perigosas (INSERT, UPDATE, etc.)
        #
        # Após validação, a query é executada no banco e retorna um array de hashes.
        data = SqlExecutionService.new(generated_sql).call

        # 3. Retorna o sucesso contendo:
        #
        # - sql: a query gerada pelo modelo (útil para auditoria e debugging)
        # - data: os resultados retornados pelo banco
        #
        # Exemplo de resposta:
        #
        # {
        #   "sql": "SELECT title FROM movies WHERE title ILIKE '%matrix%'",
        #   "data": [
        #     { "title": "The Matrix" }
        #   ]
        # }
        render json: { 
          sql: generated_sql,
          data: data 
        }, status: :ok

      rescue StandardError => e
        # Tratamento centralizado de erros.
        #
        # Possíveis falhas incluem:
        # - erro na chamada da API do Gemini
        # - SQL inválido gerado pelo modelo
        # - erro de execução no banco de dados
        # - falha na validação de segurança
        #
        # Em caso de erro, retornamos a mensagem e, se disponível,
        # a query SQL gerada para facilitar debug no frontend ou logs.
        payload = { error: e.message }

        # defined? evita erro caso a exceção ocorra antes da variável existir
        payload[:sql] = generated_sql if defined?(generated_sql)

        render json: payload, status: :bad_request
      end
    end
  end
end