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

        # Recebe o histórico de conversação enviado pelo frontend.
        # Se for a primeira mensagem, será um array vazio.
        history = params[:history] || []

        begin
          # PASSO 1: Extração do Contexto (Schema)
          # Extraímos o schema da base de dados logo no início para que ele possa ser
          # utilizado tanto pela etapa de Desambiguação quanto pela etapa de Geração de SQL.
          schema_context = DbSchemaExtractor.call(version: version)

          # PASSO 2: Análise de Intenção e Desambiguação (User Intent)
          # Agora passamos o 'history' para que a IA consiga desambiguar
          # pronomes (ex: "deles", "estes") baseada no contexto da conversa.
          intent_analysis = QueryDisambiguationService.new(
            question, 
            schema_context,
            history: history
          ).call

          # Roteamento baseado na intenção detectada:
          case intent_analysis[:intent].to_sym
          when :greeting, :off_topic
            # Responde amigavelmente sem sequer tocar no banco de dados, economizando recursos.
            render json: { 
              status: 'chat',
              message: "Olá! Sou o seu assistente inteligente de dados. Pergunte-me algo sobre os nossos filmes, atores ou diretores!",
              intent: intent_analysis[:intent]
            }, status: :ok

          when :needs_clarification
            # A pergunta foi considerada ambígua pela IA. Devolvemos a pergunta de 
            # esclarecimento para o usuário responder no chat.
            render json: { 
              status: 'clarification',
              message: intent_analysis[:clarifying_question],
              intent: intent_analysis[:intent]
            }, status: :ok

          when :ready_for_sql
            # PASSO 3: Transformação (Text-to-SQL) e Sanitização com Memória
            # O GeminiSqlService é instanciado com a pergunta, versão da arquitetura e o histórico.
            # Ele monta o prompt adequado, chama a API do Gemini,
            # remove marcações de markdown e aplica o chomp(';').
            sql_query = GeminiSqlService.new(
              question, 
              schema_context,
              history: history,
              version: version
            ).call
            
            # PASSO 4: Validação de Segurança (WAF) e Execução
            # A query limpa é repassada ao SqlExecutionService.
            # Aqui ocorre a Defesa em Profundidade: o serviço verifica se a intenção
            # é apenas de leitura (SELECT), garante que não há palavras proibidas (DROP, DELETE)
            # e bloqueia qualquer tentativa de Query Stacking (múltiplas instruções).
            # Se tudo estiver seguro, a query roda no PostgreSQL.
            results = SqlExecutionService.new(sql_query).call
            
            # PASSO 5: Resposta (Payload)
            # Retornamos o SQL gerado para ser exibido na interface de chat (útil para
            # auditoria e demonstração do motor) junto com os dados resultantes.
            render json: { 
              status: 'success',
              sql_generated: sql_query, 
              data: results,
              intent: intent_analysis[:intent]
            }, status: :ok
            
          else
            # Fallback seguro caso o modelo falhe ao estruturar o JSON de intenção.
            render json: { error: "Não foi possível compreender a intenção da mensagem." }, status: :unprocessable_entity
          end
          
        rescue StandardError => e
          # Tratamento unificado de exceções.
          # Roteamento de erros baseado no tipo de falha.
          
          if e.message.include?('GEMINI_RATE_LIMIT')
            # Se o erro for de cota estourada, retorna HTTP 429 para o frontend tratar visualmente.
            render json: { error: e.message }, status: :too_many_requests
          else
            # Qualquer outra falha (erro de sintaxe SQL, WAF, etc) cai no erro padrão 422.
            render json: { error: e.message }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end