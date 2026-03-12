require 'net/http'
require 'uri'
require 'json'

# Serviço responsável por enviar uma pergunta em linguagem natural para
# a API do Gemini e receber como resposta uma query SQL gerada pelo modelo.
#
# Este serviço faz parte de um fluxo típico de "Text-to-SQL":
# 1. Usuário faz uma pergunta em linguagem natural
# 2. O sistema fornece o schema do banco como contexto
# 3. O LLM gera uma consulta SQL
# 4. A consulta é posteriormente validada e executada em outro serviço
#
# Importante: este serviço apenas gera SQL, ele NÃO executa a query.
class GeminiSqlService
  # Endpoint da API do Gemini responsável por geração de conteúdo.
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

  # Inicializa o serviço com a pergunta do usuário e a versão da arquitetura.
  # Agora aceita o schema_context e o history para manter a memória de conversação.
  #
  # A chave da API é carregada a partir de variável de ambiente,
  # garantindo que credenciais não sejam expostas no código.
  def initialize(question, schema_context, history: [], version: :v2)
    @question = question
    @schema_context = schema_context
    @history = history
    @version = version
    @api_key = ENV.fetch('GEMINI_API_KEY') { raise "GEMINI_API_KEY não configurada" }
  end

  # Método principal do serviço.
  #
  # Fluxo:
  # 1. Extrai o schema permitido do banco com base na versão
  # 2. Constrói o prompt para o modelo
  # 3. Faz a requisição para a API do Gemini
  # 4. Extrai e sanitiza apenas a SQL da resposta
  def call
    system_instruction = build_system_instruction(@schema_context, @version)
    conversation_messages = build_conversation_history(@history, @question)
    
    response = make_api_request(system_instruction, conversation_messages)
    extract_sql(response)
  end

  private

  # Constrói o prompt de instrução do sistema (System Instruction).
  # O prompt inclui instruções rígidas de comportamento e o schema do banco,
  # mas agora é enviado separadamente da conversa para que a IA não "esqueça"
  # as regras à medida que o histórico do chat cresce.
  def build_system_instruction(schema, version)
    # Regras universais de segurança e formatação (Servem para V1 e V2)
    regras = <<~REGRAS
      1. Retorne APENAS o código SQL puro.
      2. Não inclua blocos de formatação markdown (como ```sql).
      3. Não inclua explicações, saudações ou comentários.
      4. Use apenas as tabelas e colunas fornecidas no schema abaixo.
      5. IMPORTANTE: Para filtragem de campos de texto (strings), NUNCA use o operador '='. Use SEMPRE o operador ILIKE com curingas '%' para permitir buscas parciais e ignorar maiúsculas/minúsculas.
      6. NUNCA inclua o ponto e vírgula (;) no final da query.
    REGRAS

    # Regras específicas injetadas apenas na V2 (Arquitetura Relacional)
    if version == :v2
      regras += <<~REGRAS_V2
        7. IMPORTANTE: Como o banco é relacional, use JOINs apropriados. Sempre qualifique os nomes das colunas com o nome da tabela (ex: atores.nome, filmes.titulo) para evitar ambiguidade.
        8. Se a pergunta for em português, mantenha a lógica sobre as tabelas em português.
      REGRAS_V2
    end

    <<~INSTRUCTION
      Você é um especialista em banco de dados PostgreSQL. 
      Sua única tarefa é traduzir perguntas em linguagem natural para consultas SQL válidas.
      
      Regras estritas:
      #{regras}
      
      Schema do Banco de Dados:
      #{schema}
    INSTRUCTION
  end

  # Constrói a estrutura de mensagens esperada pela API do Gemini,
  # concatenando o histórico antigo com a nova pergunta do usuário.
  def build_conversation_history(history, current_question)
    formatted_history = ChatMemoryBuilderService.new(history).call
    
    formatted_history << {
      role: 'user',
      parts: [{ text: current_question }]
    }

    formatted_history
  end

  # Responsável por realizar a chamada HTTP para a API do Gemini.
  # Aqui montamos manualmente a requisição utilizando Net::HTTP.
  def make_api_request(system_instruction, messages)
    uri = URI(API_URL)
    request = Net::HTTP::Post.new(uri)
    
    # Passamos a chave de autenticação através do Header HTTP 'x-goog-api-key'.
    # Isso impede que a chave seja registrada nos logs de erro do servidor (como HTTP 422 ou 500)
    # caso a requisição falhe e a URL seja impressa no terminal.
    request['Content-Type'] = 'application/json'
    request['x-goog-api-key'] = @api_key
    
    request.body = {
      system_instruction: { parts: [{ text: system_instruction }] },
      contents: messages
    }.to_json

    # Executa a requisição HTTPS
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parsed_response = JSON.parse(response.body) rescue {}

    # Validação da resposta HTTP com roteamento de erro 429 (Rate Limit).
    unless response.is_a?(Net::HTTPSuccess)
      error_message = parsed_response.dig('error', 'message') || response.message || "Erro desconhecido na resposta da API"
      
      if response.code.to_i == 429
        raise StandardError, "GEMINI_RATE_LIMIT: #{error_message}"
      else
        raise StandardError, "Erro de IA (SQL) [HTTP #{response.code}]: #{error_message}"
      end
    end

    parsed_response
  end

  # Extrai e sanitiza o SQL da resposta.
  #
  # Fazemos uma limpeza preventiva do markdown e usamos o chomp(';')
  # para remover o terminador apenas se ele estiver no final da string.
  # Isso impede o bloqueio incorreto pelo SqlExecutionService, enquanto
  # mantém a defesa contra Query Stacking.
  def extract_sql(api_response)
    raw_text = api_response.dig('candidates', 0, 'content', 'parts', 0, 'text') || ""
    
    raw_text.gsub(/```sql\n?/, '').gsub(/```/, '').strip.chomp(';')
  end
end