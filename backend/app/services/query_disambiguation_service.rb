require 'net/http'
require 'uri'
require 'json'

# Serviço responsável por analisar a intenção do usuário antes da geração do SQL.
# Baseado em técnicas de "Disambiguation using LLMs", este serviço impede
# alucinações ao avaliar se a pergunta do usuário é clara o suficiente
# dado o schema do banco, ou se requer uma pergunta de esclarecimento (follow-up).
class QueryDisambiguationService
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

  def initialize(question, schema_context)
    @question = question
    @schema_context = schema_context
    @api_key = ENV.fetch('GEMINI_API_KEY') { raise "GEMINI_API_KEY não configurada" }
  end

  # Retorna um Hash estruturado com o status da intenção detectada pela IA.
  def call
    prompt = build_disambiguation_prompt
    response = make_api_request(prompt)
    extract_json_response(response)
  end

  private

  # Monta o prompt solicitando que a IA responda obrigatoriamente
  # em formato JSON seguindo as regras de roteamento do sistema.
  def build_disambiguation_prompt
    <<~PROMPT
      Você é o classificador de intenções e desambiguador de um assistente de banco de dados.
      Sua tarefa é analisar a pergunta do usuário frente ao schema do banco e decidir o que fazer.
      
      Schema Disponível:
      #{@schema_context}
      
      Regras:
      1. Se a pergunta for um cumprimento ou fora do tópico (off-topic), retorne o intent apropriado.
      2. Se a pergunta sobre os dados for ambígua ou faltar parâmetros (ex: "melhores filmes" sem definir como medir isso), defina intent = "needs_clarification" e forneça uma "clarifying_question".
      3. Se a pergunta for clara e totalmente possível de ser respondida usando APENAS as tabelas do schema, defina intent = "ready_for_sql".

      Você DEVE responder APENAS com um JSON válido, usando exatamente esta estrutura:
      {
        "intent": "greeting" | "off_topic" | "needs_clarification" | "ready_for_sql",
        "clarifying_question": "A pergunta que você fará ao usuário para desambiguar (deixe nulo se não precisar)",
        "reasoning": "Sua explicação interna e curta do porquê tomou essa decisão"
      }
      
      Pergunta do usuário: "#{@question}"
    PROMPT
  end

  def make_api_request(prompt)
    uri = URI(API_URL)
    request = Net::HTTP::Post.new(uri)
    
    # Proteção da credencial trafegando a chave via Header.
    # Evita exposição acidental da API Key em stack traces ou logs do Rails.
    request['Content-Type'] = 'application/json'
    request['x-goog-api-key'] = @api_key
    
    request.body = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: "application/json" }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    parsed_response = JSON.parse(response.body) rescue {}

    # Tratamento de erro detalhado com suporte ao status 429 (Rate Limit).
    unless response.is_a?(Net::HTTPSuccess)
      error_message = parsed_response.dig('error', 'message') || response.message || "Erro desconhecido na resposta da API"
      
      if response.code.to_i == 429
        raise StandardError, "GEMINI_RATE_LIMIT: #{error_message}"
      else
        raise StandardError, "Erro de IA (Desambiguação) [HTTP #{response.code}]: #{error_message}"
      end
    end

    parsed_response
  end

  def extract_json_response(api_response)
    raw_text = api_response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    JSON.parse(raw_text, symbolize_names: true)
  rescue JSON::ParserError
    # Fallback seguro caso o LLM falhe ao formatar o JSON corretamente.
    { intent: :off_topic, clarifying_question: nil, reasoning: "Falha na conversão da resposta do LLM." }
  end
end