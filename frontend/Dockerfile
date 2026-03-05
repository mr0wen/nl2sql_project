# frontend/Dockerfile
FROM node:20

WORKDIR /app

# Copia os arquivos de dependência e instala os pacotes
COPY package.json package-lock.json* ./
RUN npm install

# Copia o resto da aplicação
COPY . .

# Expõe a porta do Vite
EXPOSE 5173

# Comando padrão para iniciar o Vite em modo host
CMD ["npm", "run", "dev", "--", "--host"]