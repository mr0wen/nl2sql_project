require 'net/http'
require 'uri'
require 'json'

# Serviço responsável por enviar uma pergunta em linguagem natural para
# a API do Gemini e receber como resposta uma query SQL gerada pelo modelo.
#
# Este serviço faz parte de um fluxo típico de "Text-to-SQL":
#
# 1. Usuário faz uma pergunta em linguagem natural
# 2. O sistema fornece o schema do banco como contexto
# 3. O LLM gera uma consulta SQL
# 4. A consulta é posteriormente validada e executada em outro serviço
#
# Importante: este serviço apenas gera SQL, ele NÃO executa a query.
class GeminiSqlService
  # Endpoint da API do Gemini responsável por geração de conteúdo.
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

  # Inicializa o serviço com a pergunta do usuário.
  #
  # A chave da API é carregada a partir de variável de ambiente,
  # garantindo que credenciais não sejam expostas no código.
  def initialize(question)
    @question = question
    @api_key = ENV.fetch('GEMINI_API_KEY') { raise "GEMINI_API_KEY não configurada" }
  end

  # Método principal do serviço.
  #
  # Fluxo:
  # 1. Extrai o schema permitido do banco
  # 2. Constrói o prompt para o modelo
  # 3. Faz a requisição para a API do Gemini
  # 4. Extrai apenas a SQL da resposta
  def call
    schema_context = DbSchemaExtractor.call
    prompt = build_prompt(schema_context, @question)
    
    response = make_api_request(prompt)
    extract_sql(response)
  end

  private

  # Constrói o prompt enviado ao LLM.
  #
  # O prompt inclui:
  # - Instruções rígidas de comportamento
  # - Schema do banco
  # - Pergunta do usuário
  #
  # O objetivo é reduzir alucinações do modelo e garantir
  # que a saída seja somente SQL executável.
  def build_prompt(schema, question)
    <<~PROMPT
      Você é um especialista em banco de dados PostgreSQL. 
      Sua única tarefa é traduzir perguntas em linguagem natural para consultas SQL válidas.
      
      Regras estritas:
      1. Retorne APENAS o código SQL puro.
      2. Não inclua blocos de formatação markdown (como ```sql).
      3. Não inclua explicações, saudações ou comentários.
      4. Use apenas as tabelas e colunas fornecidas no schema abaixo.
      5. IMPORTANTE: Para filtragem de campos de texto (strings), NUNCA use o operador '='. Use SEMPRE o operador ILIKE com curingas '%' para permitir buscas parciais e ignorar maiúsculas/minúsculas (exemplo: ILIKE '%termo%').
      
      Schema do Banco de Dados:
      #{schema}
      
      Pergunta do usuário: "#{@question}"
      
      Query SQL:
    PROMPT
  end

  # Responsável por realizar a chamada HTTP para a API do Gemini.
  #
  # Aqui montamos manualmente a requisição HTTP utilizando Net::HTTP,
  # enviando o prompt no formato esperado pela API.
  def make_api_request(prompt)
    uri = URI("#{API_URL}?key=#{@api_key}")
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    
    # Estrutura do payload esperada pela API do Gemini:
    # contents -> parts -> text
    request.body = {
      contents: [{ parts: [{ text: prompt }] }]
    }.to_json

    # Executa a requisição HTTPS
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parsed_response = JSON.parse(response.body)

    # Validação da resposta HTTP.
    #
    # Caso a API retorne erro (ex: chave inválida, limite de quota,
    # erro de request), capturamos a mensagem real retornada pelo Google
    # e interrompemos o fluxo.
    unless response.is_a?(Net::HTTPSuccess)
      error_message = parsed_response.dig('error', 'message') || response.message
      raise StandardError, "Erro na API do Gemini: #{error_message}"
    end

    parsed_response
  end

  # Extrai o SQL da resposta retornada pelo Gemini.
  #
  # Estrutura típica da resposta:
  #
  # candidates -> content -> parts -> text
  #
  # O modelo às vezes ignora instruções e retorna markdown
  # com blocos ```sql, então fazemos uma limpeza preventiva.
  def extract_sql(api_response)
    raw_text = api_response.dig('candidates', 0, 'content', 'parts', 0, 'text') || ""
    
    # Remove blocos markdown caso o modelo tenha incluído
    raw_text.gsub(/```sql\n?/, '').gsub(/```/, '').strip
  end
end