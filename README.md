# CineGestor

O CineGestor é um aplicativo Flutter desenvolvido para auxiliar na gestão e manutenção de assentos em salas de cinema. Com ele, é possível registrar problemas, acompanhar o histórico de manutenções e gerenciar diferentes salas de cinema de forma eficiente.

## 🚀 Funcionalidades

- **Autenticação de Usuários**
  - Sistema de login seguro
  - Credenciais padrão: admin@cinegestor.com / admin123

- **Gestão de Salas**
  - Visualização de todas as salas disponíveis
  - Detalhamento da quantidade de fileiras por sala
  - Interface intuitiva para seleção de salas

- **Manutenção de Assentos**
  - Registro de problemas em assentos específicos
  - Classificação de urgência (Alta, Média, Baixa)
  - Adição de observações detalhadas
  - Sistema de cores para identificação rápida de problemas

- **Histórico de Manutenções**
  - Visualização completa do histórico de problemas
  - Filtro por sala e assento
  - Detalhes de data e hora dos registros
  - Indicadores visuais de urgência

## 🛠️ Tecnologias Utilizadas

- Flutter
- Provider (Gerenciamento de Estado)
- Material Design
- Intl (Formatação de datas)

## 📋 Pré-requisitos

Para executar o projeto, você precisará ter instalado:

- Flutter SDK
- Dart SDK
- Dependências do sistema para Linux:
  - libstdc++-12-dev
  - build-essential
  - cmake
  - ninja-build
  - pkg-config
  - libgtk-3-dev

## 🔧 Instalação

1. Clone o repositório:
```bash
git clone [URL_DO_REPOSITÓRIO]
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Execute o aplicativo:
```bash
flutter run
```

## 📱 Estrutura de Navegação

- `/` - Página de Login
- `/rooms` - Seleção de Salas
- `/maintenance` - Página de Manutenção
- `/history` - Histórico de Manutenções

## 🎨 Temas e Personalização

O aplicativo utiliza um tema personalizado (AppTheme) que mantém a consistência visual em toda a aplicação, seguindo as diretrizes do Material Design.

## 🤝 Contribuição

1. Faça um Fork do projeto
2. Crie uma Branch para sua Feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a Branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## ✨ Próximos Passos

- [ ] Implementar sistema de múltiplos usuários
- [ ] Adicionar dashboard com estatísticas
- [ ] Implementar sistema de notificações
- [ ] Implementar backup automático dos dados

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para mais detalhes.

## 📞 Suporte

Para suporte e dúvidas, por favor abra uma issue no repositório do projeto.
