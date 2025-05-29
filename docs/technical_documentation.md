# Documentação Técnica - CineGestor

## Arquitetura do Projeto

### Estrutura de Diretórios

```
lib/
├── controllers/      # Controladores de estado e lógica de negócios
├── models/          # Modelos de dados
├── pages/           # Telas do aplicativo
├── widgets/         # Widgets reutilizáveis
└── themes/          # Configurações de tema
```

## Componentes Principais

### Controllers

#### AuthController
- Gerencia o estado de autenticação
- Implementa lógica de login/logout
- Mantém estado de autenticação usando ChangeNotifier

#### RoomController
- Gerencia o estado das salas
- Controla a lista de problemas de manutenção
- Implementa operações CRUD para salas e problemas

### Models

#### Room
- Representa uma sala de cinema
- Contém informações sobre fileiras e assentos
- Mantém estado dos assentos

#### MaintenanceIssue
- Representa um problema de manutenção
- Armazena informações como:
  - ID da sala
  - ID do assento
  - Tipo do problema
  - Nível de urgência
  - Data e hora
  - Observações

### Pages

#### LoginPage (/)
- Implementa autenticação básica
- Validação de campos
- Redirecionamento após login

#### RoomSelectionPage (/rooms)
- Lista todas as salas disponíveis
- Implementa menu de navegação
- Permite seleção de sala para manutenção

#### MaintenancePage (/maintenance)
- Exibe grid de assentos
- Permite registro de problemas
- Interface para seleção de tipo de problema e urgência

#### HistoryPage (/history)
- Lista histórico de manutenções
- Implementa filtros e ordenação
- Exibe detalhes de cada registro

### Widgets

#### ChairWidget
- Componente reutilizável para assentos
- Estados: normal, com problema, selecionado
- Interativo com feedback visual

### Temas

#### AppTheme
- Define esquema de cores
- Configurações de tipografia
- Estilos de componentes

## Fluxo de Dados

1. **Autenticação**
   ```
   LoginPage -> AuthController -> RoomSelectionPage
   ```

2. **Seleção de Sala**
   ```
   RoomSelectionPage -> RoomController -> MaintenancePage
   ```

3. **Registro de Problema**
   ```
   MaintenancePage -> RoomController -> HistoryPage
   ```

## Gerenciamento de Estado

- Utiliza Provider para gerenciamento de estado
- ChangeNotifier para atualizações reativas
- Estado global mantido nos controllers

## Boas Práticas

### Código
- Nomes descritivos para variáveis e funções
- Comentários em seções complexas
- Separação de responsabilidades
- Reutilização de widgets

### UI/UX
- Feedback visual para ações
- Indicadores de carregamento
- Tratamento de erros com mensagens claras
- Design responsivo

## Testes

### Tipos de Testes Recomendados
- Testes unitários para controllers
- Testes de widget para componentes
- Testes de integração para fluxos completos

## Manutenção

### Logs
- Implementar sistema de logs para:
  - Erros de autenticação
  - Registros de manutenção
  - Ações do usuário

### Backup
- Implementar sistema de backup para:
  - Dados de salas
  - Histórico de manutenções
  - Configurações do sistema

## Segurança

### Autenticação
- Sistema básico de login
- Proteção de rotas
- Validação de dados de entrada

### Dados
- Validação de entrada de dados
- Sanitização de inputs
- Proteção contra injeção de dados maliciosos

## Performance

### Otimizações
- Lazy loading de imagens
- Paginação de listas longas
- Cache de dados frequentes

## Considerações de Desenvolvimento

### Ambiente de Desenvolvimento
- Flutter SDK atualizado
- VS Code ou Android Studio
- Flutter DevTools para debugging

### Dependências Principais
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  intl: ^0.17.0
```

### Comandos Úteis
```bash
# Atualizar dependências
flutter pub get

# Executar testes
flutter test

# Construir release
flutter build
``` 