FROM nginx:alpine

COPY build/web /usr/share/nginx/html

# Create the .env file Flutter Web expects at runtime
# Set SUPABASE_URL, SUPABASE_ANON_KEY, GEMINI_API_KEY as env vars in Render
RUN mkdir -p /usr/share/nginx/html/assets/assets && \
    echo "SUPABASE_URL=${SUPABASE_URL}" > /usr/share/nginx/html/assets/assets/.env && \
    echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" >> /usr/share/nginx/html/assets/assets/.env && \
    echo "GROQ_API_KEY=${GROQ_API_KEY}" >> /usr/share/nginx/html/assets/assets/.env

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]