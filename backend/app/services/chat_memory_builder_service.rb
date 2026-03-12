# Serviço responsável por converter o histórico de chat vindo do Frontend
# para o formato estruturado 'contents' exigido pela API do Google Gemini.
#
# A API do Gemini espera um array alternando entre as roles "user" e "model" 
# para manter o contexto de conversação (Stateless Memory).
class ChatMemoryBuilderService
  # Inicializa o serviço com o histórico enviado via payload pelo React.
  # @param history [Array<Hash>] Ex: [{ role: 'user', content: 'Oi' }, { role: 'assistant', content: 'Olá' }]
  def initialize(history = [])
    @history = history || []
  end

  # Retorna o array formatado pronto para ser embutido no request body do Gemini.
  def call
    formatted_history = []

    @history.each do |message|
      # Ignora mensagens de erro visuais geradas no frontend para não poluir
      # a memória da IA com logs técnicos ou mensagens de bloqueio locais.
      next if message[:isError] 

      # Mapeia as roles da interface (assistant) para as roles oficiais da API (model)
      role = message[:role] == 'assistant' ? 'model' : 'user'
      
      formatted_history << {
        role: role,
        parts: [{ text: message[:content] }]
      }
    end

    formatted_history
  end
end