import { useState, useRef, useEffect } from 'react';
import { Send, Terminal, Database, Loader2, GitBranch } from 'lucide-react';

// Tipagem para as mensagens do chat
type Message = {
  id: number;
  role: 'user' | 'assistant';
  content: string;
  sql?: string | null;
  data?: any[];
  isError?: boolean;
};

function App() {
  const [prompt, setPrompt] = useState('');
  const [version, setVersion] = useState<'v1' | 'v2'>('v2'); // Controle de Fase
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Auto-scroll para a última mensagem
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!prompt.trim()) return;

    const userMessage: Message = { id: Date.now(), role: 'user', content: prompt };
    setMessages((prev) => [...prev, userMessage]);
    setPrompt('');
    setIsLoading(true);

    try {
      const response = await fetch('http://localhost:3000/api/v1/queries', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        // Enviando a versão selecionada para a API
        body: JSON.stringify({ question: userMessage.content, version }),
      });

      const result = await response.json();

      if (!response.ok) throw new Error(result.error || 'Erro desconhecido ao processar query');

      const assistantMessage: Message = {
        id: Date.now() + 1,
        role: 'assistant',
        content: `Aqui está o resultado da sua consulta (utilizando a arquitetura ${version.toUpperCase()}):`,
        // Garante compatibilidade caso o backend retorne sql ou sql_generated
        sql: result.sql || result.sql_generated, 
        data: result.data,
      };
      
      setMessages((prev) => [...prev, assistantMessage]);
    } catch (error: any) {
      setMessages((prev) => [
        ...prev,
        { id: Date.now() + 1, role: 'assistant', content: error.message, isError: true },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-screen bg-gray-900 text-gray-100 font-sans">
      
      {/* Header com Toggle de Versão */}
      <header className="flex items-center justify-between p-4 bg-gray-800 border-b border-gray-700 shadow-sm">
        <div className="flex items-center">
          <Database className="w-6 h-6 mr-3 text-emerald-400" />
          <h1 className="text-xl font-semibold">Assistente NL2SQL</h1>
        </div>
        
        {/* Toggle UI */}
        <div className="flex items-center bg-gray-900 rounded-lg p-1 border border-gray-700">
          <GitBranch className="w-4 h-4 mr-2 text-gray-500 ml-2" />
          <button
            onClick={() => setVersion('v1')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              version === 'v1' ? 'bg-gray-700 text-white shadow' : 'text-gray-400 hover:text-gray-200'
            }`}
          >
            Fase 1 (Flat)
          </button>
          <button
            onClick={() => setVersion('v2')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              version === 'v2' ? 'bg-gray-700 text-white shadow' : 'text-gray-400 hover:text-gray-200'
            }`}
          >
            Fase 2 (Relacional)
          </button>
        </div>
      </header>

      {/* Área do Chat */}
      <main className="flex-1 overflow-y-auto p-4 md:p-8 space-y-6">
        {messages.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full text-gray-500">
            <Database className="w-16 h-16 mb-4 opacity-20" />
            <p className="text-lg">Faça uma pergunta sobre o banco de dados de filmes.</p>
            <p className="text-sm">Ex: "Qual o filme mais antigo?" ou "Top 3 de bilheteria do Christopher Nolan"</p>
          </div>
        )}

        {messages.map((msg) => (
          <div key={msg.id} className={`flex max-w-4xl mx-auto ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`rounded-lg p-5 w-full md:w-4/5 ${msg.role === 'user' ? 'bg-gray-800 border border-gray-700' : 'bg-transparent'}`}>
              
              {/* Identificação de quem está falando */}
              <div className="flex items-center mb-3 text-sm font-medium">
                {msg.role === 'user' ? (
                  <span className="text-blue-400">Você</span>
                ) : (
                  <span className={msg.isError ? 'text-red-400' : 'text-emerald-400'}>Assistente</span>
                )}
              </div>

              {/* Mensagem de texto */}
              <p className="mb-4 text-gray-200">{msg.content}</p>

              {/* Bloco de Código SQL */}
              {msg.sql && (
                <div className="mb-4 rounded-md bg-gray-950 border border-gray-800 overflow-hidden">
                  <div className="flex items-center bg-gray-800 px-4 py-2 text-xs text-gray-400">
                    <Terminal className="w-4 h-4 mr-2" /> PostgreSQL
                  </div>
                  <pre className="p-4 text-sm font-mono text-emerald-300 overflow-x-auto whitespace-pre-wrap">
                    <code>{msg.sql}</code>
                  </pre>
                </div>
              )}

              {/* Tabela de Dados Dinâmica */}
              {msg.data && msg.data.length > 0 && (
                <div className="overflow-x-auto rounded-md border border-gray-700 bg-gray-800">
                  <table className="min-w-full text-left text-sm">
                    <thead className="bg-gray-900 border-b border-gray-700 text-gray-300">
                      <tr>
                        {Object.keys(msg.data[0]).map((key) => (
                          <th key={key} className="px-4 py-3 font-medium uppercase tracking-wider">{key}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-700">
                      {msg.data.map((row, i) => (
                        <tr key={i} className="hover:bg-gray-700/50 transition-colors">
                          {Object.values(row).map((val: any, j) => (
                            <td key={j} className="px-4 py-3 text-gray-300">{String(val)}</td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              {/* Fallback se a query rodar mas não achar nada */}
              {msg.data && msg.data.length === 0 && !msg.isError && (
                <div className="p-4 border border-yellow-700 bg-yellow-900/20 text-yellow-500 rounded-md text-sm">
                  A consulta foi executada, mas não retornou nenhum resultado.
                </div>
              )}
            </div>
          </div>
        ))}
        
        {isLoading && (
          <div className="flex max-w-4xl mx-auto justify-start">
            <div className="flex items-center space-x-2 text-gray-500 p-5">
              <Loader2 className="w-5 h-5 animate-spin text-emerald-500" />
              <span>Gerando query SQL...</span>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </main>

      {/* Área de Input Fixa */}
      <footer className="p-4 bg-gray-800 border-t border-gray-700">
        <div className="max-w-4xl mx-auto relative">
          <form onSubmit={handleSubmit} className="relative flex items-center">
            <input
              type="text"
              value={prompt}
              onChange={(e) => setPrompt(e.target.value)}
              disabled={isLoading}
              placeholder="Pergunte ao banco de dados em linguagem natural..."
              className="w-full bg-gray-900 border border-gray-700 rounded-xl py-4 pl-5 pr-14 text-gray-100 focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:border-emerald-500 disabled:opacity-50 transition-all shadow-inner"
            />
            <button
              type="submit"
              disabled={isLoading || !prompt.trim()}
              className="absolute right-2 p-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <Send className="w-5 h-5" />
            </button>
          </form>
          <div className="text-center mt-2 text-xs text-gray-500">
            A IA pode cometer erros. Verifique a query SQL gerada. O motor de segurança impede comandos maliciosos.
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;