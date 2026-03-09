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
  #
  # A chave da API é carregada a partir de variável de ambiente,
  # garantindo que credenciais não sejam expostas no código.
  def initialize(question, version: :v2)
    @question = question
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
    schema_context = DbSchemaExtractor.call(version: @version)
    prompt = build_prompt(schema_context, @question, @version)
    
    response = make_api_request(prompt)
    extract_sql(response)
  end

  private

  # Constrói o prompt enviado ao LLM.
  #
  # O prompt inclui instruções rígidas de comportamento, o schema do banco
  # e a pergunta do usuário. O objetivo é reduzir alucinações e garantir SQL executável.
  def build_prompt(schema, question, version)
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

    <<~PROMPT
      Você é um especialista em banco de dados PostgreSQL. 
      Sua única tarefa é traduzir perguntas em linguagem natural para consultas SQL válidas.
      
      Regras estritas:
      #{regras}
      
      Schema do Banco de Dados:
      #{schema}
      
      Pergunta do usuário: "#{question}"
      
      Query SQL:
    PROMPT
  end

  # Responsável por realizar a chamada HTTP para a API do Gemini.
  # Aqui montamos manualmente a requisição utilizando Net::HTTP.
  def make_api_request(prompt)
    uri = URI("#{API_URL}?key=#{@api_key}")
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    
    # Estrutura do payload esperada pela API do Gemini: contents -> parts -> text
    request.body = {
      contents: [{ parts: [{ text: prompt }] }]
    }.to_json

    # Executa a requisição HTTPS
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parsed_response = JSON.parse(response.body)

    # Validação da resposta HTTP capturando a mensagem de erro do Google.
    unless response.is_a?(Net::HTTPSuccess)
      error_message = parsed_response.dig('error', 'message') || response.message
      raise StandardError, "Erro na API do Gemini: #{error_message}"
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