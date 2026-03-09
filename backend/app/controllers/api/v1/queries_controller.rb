module Api
  module V1
    # Controller responsável por receber as perguntas em linguagem natural do frontend,
    # orquestrar a geração do SQL via Inteligência Artificial e a execução segura
    # no banco de dados.
    #
    # Para fins de demonstração acadêmica e arquitetural, este endpoint suporta
    # duas fases distintas de modelagem de dados, controladas pelo parâmetro 'version':
    # - :v1 -> Arquitetura Flat (Tabela única 'movies')
    # - :v2 -> Arquitetura Relacional (Tabelas normalizadas: filmes, atores, etc. com JOINs)
    class QueriesController < ApplicationController
      def create
        # Extrai a string com a pergunta em linguagem natural feita pelo usuário.
        question = params[:question]
        
        # Captura a versão enviada pelo frontend (ex: 'v1' ou 'v2').
        # Converte para símbolo para facilitar o uso interno nos serviços.
        # Se nenhuma versão for informada, assume :v2 como padrão.
        version = params[:version].present? ? params[:version].to_sym : :v2

        begin
          # PASSO 1: Transformação (Text-to-SQL) e Sanitização
          # O GeminiSqlService é instanciado com a pergunta e a versão da arquitetura.
          # Ele extrai o schema correto, monta o prompt adequado, chama a API do Gemini,
          # remove marcações de markdown e aplica o chomp(';') para evitar que um terminador
          # inofensivo acione o bloqueio de segurança na próxima etapa.
          sql_query = GeminiSqlService.new(question, version: version).call
          
          # PASSO 2: Validação de Segurança (WAF) e Execução
          # A query limpa é repassada ao SqlExecutionService.
          # Aqui ocorre a Defesa em Profundidade: o serviço verifica se a intenção
          # é apenas de leitura (SELECT), garante que não há palavras proibidas (DROP, DELETE)
          # e bloqueia qualquer tentativa de Query Stacking (múltiplas instruções).
          # Se tudo estiver seguro, a query roda no PostgreSQL.
          results = SqlExecutionService.new(sql_query).call
          
          # PASSO 3: Resposta (Payload)
          # Retornamos o SQL gerado para ser exibido na interface de chat (útil para
          # auditoria e demonstração do motor) junto com os dados resultantes.
          render json: { 
            sql_generated: sql_query, 
            data: results 
          }, status: :ok
          
        rescue StandardError => e
          # Tratamento unificado de exceções.
          # Qualquer falha no processo (seja um timeout na API da IA, um bloqueio
          # de segurança do WAF ou um erro de sintaxe retornado pelo banco de dados)
          # cai aqui e é devolvida como um erro amigável HTTP 422 para o frontend.
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end
    end
  end
end