require 'net/http'
require 'uri'
require 'json'

# Serviço responsável por analisar a intenção do usuário antes da geração do SQL.
# Baseado em técnicas de "Disambiguation using LLMs", este serviço impede
# alucinações ao avaliar se a pergunta do usuário é clara o suficiente
# dado o schema do banco, ou se requer uma pergunta de esclarecimento (follow-up).
class QueryDisambiguationService
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

  # Inicializador agora aceita o histórico de conversação
  def initialize(question, schema_context, history: [])
    @question = question
    @schema_context = schema_context
    @history = history
    @api_key = ENV.fetch('GEMINI_API_KEY') { raise "GEMINI_API_KEY não configurada" }
  end

  # Retorna um Hash estruturado com o status da intenção detectada pela IA.
  def call
    system_instruction = build_system_instruction
    messages = build_conversation_history(@history, @question)
    
    response = make_api_request(system_instruction, messages)
    extract_json_response(response)
  end

  private

  # As regras passam a ser o System Instruction, garantindo que a IA
  # saiba que deve analisar a pergunta ATUAL levando em conta o HISTÓRICO.
  def build_system_instruction
    <<~PROMPT
      Você é o classificador de intenções e desambiguador de um assistente de banco de dados.
      Sua tarefa é analisar a pergunta ATUAL do usuário frente ao schema do banco e ao contexto do histórico da conversa.
      
      Schema Disponível:
      #{@schema_context}
      
      Regras:
      1. Se a pergunta for um cumprimento ou fora do tópico (off-topic), defina intent = "greeting" ou "off_topic".
      2. Se a pergunta sobre os dados for ambígua e a resposta NÃO estiver óbvia no histórico da conversa, defina intent = "needs_clarification" e forneça uma "clarifying_question".
      3. IMPORTANTE: Se a pergunta usar pronomes (ex: "notas deles?", "e os outros?") mas o contexto estiver CLARO no histórico (ex: o usuário acabou de perguntar sobre atores/diretores), defina intent = "ready_for_sql". Não peça esclarecimentos se a resposta já estiver no contexto.

      Você DEVE responder APENAS com um JSON válido, usando exatamente esta estrutura:
      {
        "intent": "greeting" | "off_topic" | "needs_clarification" | "ready_for_sql",
        "clarifying_question": "A pergunta que você fará ao usuário para desambiguar (deixe nulo se não precisar)",
        "reasoning": "Sua explicação interna e curta do porquê tomou essa decisão"
      }
    PROMPT
  end

  # Formata o histórico usando o construtor de memória existente
  def build_conversation_history(history, current_question)
    formatted_history = ChatMemoryBuilderService.new(history).call
    
    formatted_history << {
      role: 'user',
      parts: [{ text: current_question }]
    }

    formatted_history
  end

  def make_api_request(system_instruction, messages)
    uri = URI(API_URL)
    request = Net::HTTP::Post.new(uri)
    
    # Proteção da credencial trafegando a chave via Header.
    # Evita exposição acidental da API Key em stack traces ou logs do Rails.
    request['Content-Type'] = 'application/json'
    request['x-goog-api-key'] = @api_key
    
    # Estrutura com System Instruction + Memory + JSON Output MimeType
    request.body = {
      system_instruction: { parts: [{ text: system_instruction }] },
      contents: messages,
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