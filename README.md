# CineGestor

O **CineGestor** é uma aplicação Flutter para gestão e manutenção de assentos em salas de cinema. Ele permite mapear salas reais em formato de matriz (grid fiel ao padrão da Ingresso.com), controlar permissões por cargo (RBAC), receber solicitações da equipe de operação em uma área de triagem (*Staging*) e acompanhar o ciclo de vida completo das manutenções.

---

## 🚀 Funcionalidades Implementadas (MVP)

### 1. Autenticação e Controle de Acesso (4 Perfis / RBAC)
- Sessão persistente local (`SharedPreferences`).
- Isolamento de salas pelo `cinemaId` do funcionário logado.
- **4 níveis de acesso:**
  - **Operação (Limpeza / Portaria):** Abre solicitações rápidas que entram na fila de **Triagem (*Staging*)**.
  - **Assistente de Manutenção:** Registra problemas diretamente como manutenção ativa e consulta a fila de trabalho.
  - **Encarregado:** Avalia a fila de **Triagem** (aprova ou recusa solicitações da operação), registra demandas e conclui manutenções (**Resolver**).
  - **Gerente Geral:** Acesso total — aprova triagem, resolve manutenções, **reabre** chamados concluídos, **exclui** registros e exporta relatórios.

| Perfil | E-mail / Usuário de Teste | Senha |
| :--- | :--- | :--- |
| **Operação** | `operacao@cinegestor.com` | `123` |
| **Assistente** | `assistente@cinegestor.com` | `123` |
| **Encarregado** | `encarregado@cinegestor.com` | `123` |
| **Gerente** | `gerente@cinegestor.com` ou `admin` | `123` |

### 2. Lobby de Salas e Mini-Dashboard (`RoomSelectionPage`)
- Cabeçalho identificando o funcionário logado, seu cargo e sua unidade (`UCI Park Campo Grande`).
- **Mini-Dashboard em tempo real:**
  - Total de salas da unidade.
  - Total e percentual (`%`) de assentos operacionais (dos **1.671 assentos** mapeados nas 7 salas).
  - Total de manutenções ativas e assentos afetados.
  - Contador de solicitações aguardando na fila de **Triagem**.
- Cards responsivos (Mobile, Tablet e Desktop) com badges de status por sala (*100% operacional*, *X em triagem*, *X em manutenção*).

### 3. Mapa Fiel em Matriz / Grid (`MaintenancePage`)
- Renderização exata por coordenadas `(line, column)` extraídas da estrutura da Ingresso.com (`assets/cinemas/uci_park_campo_grande/sala_1.json` a `sala_7.json`).
- Representação fiel de corredores verticais, corredores horizontais, recuos laterais, letras de fileira duplas e posição da tela (`stage`).
- **Legenda e diferenciação visual de assentos:**
  - 🟢 **Normal** (`Regular`)
  - 🔵 **Cadeirante** (`Disability`)
  - 🟠 **Acompanhante** (`Companion`)
  - 🟡 **Obeso** (`Obese`)
  - 🟨 **Em Triagem** (`Staging` — solicitação aberta pela Operação)
  - 🔴 **Com Defeito** (`Active` — manutenção confirmada)
  - 🟣 **Selecionado**
- Controles interativos de Zoom (`+`, `-`, `Reset`) e visualização/aprovação/resolução rápida de chamados ao tocar em qualquer assento.

### 4. Área de Triagem / Staging (`StagingPage`)
- Tela dedicada para **Encarregados** e **Gerentes** avaliarem as solicitações abertas pela equipe de **Operação**.
- Aprovação com 1 clique (transforma a solicitação em manutenção ativa e pinta o assento de vermelho) ou recusa/arquivamento.

### 5. Histórico e Exportação de Relatórios (`HistoryPage`)
- Filtros combinados por **Sala**, **Status** (*Todos, Em Triagem, Em Manutenção, Resolvidos*) e **Urgência** (*Alta, Média, Baixa*).
- Registro de quem reportou (`reportedBy` / `reportedRole`), data/hora de abertura e data/hora de conclusão (`resolvedAt` / `resolvedBy`).
- **Exportação de Relatório:** Gera um relatório formatado em texto (respeitando os filtros selecionados) pronto para copiar para a área de transferência e compartilhar via WhatsApp ou e-mail.

---

## 📁 Estrutura do Projeto

```text
lib/
├── controllers/
│   ├── auth_controller.dart       # Autenticação, sessão e perfis de usuário
│   └── room_controller.dart       # Estado das salas, assentos, triagem e manutenções
├── models/
│   ├── app_user.dart              # Modelo de usuário (AppUser) e permissões (UserRole)
│   ├── maintenance_issue.dart     # Modelo de chamado (MaintenanceIssue) e status (IssueStatus)
│   ├── room.dart                  # Modelo de sala com suporte a Grid (Ingresso.com) e legado
│   └── seat.dart                  # Modelo de assento com coordenadas (line, column) e tipo
├── pages/
│   ├── login_page.dart            # Tela de login com chips de acesso rápido para teste
│   ├── room_selection_page.dart   # Lobby com mini-dashboard e seleção de salas
│   ├── maintenance_page.dart      # Mapa interativo da sala e formulário de manutenção
│   ├── staging_page.dart          # Fila de triagem (aprovação/recusa de solicitações)
│   └── history_page.dart          # Histórico com filtros, ações por cargo e exportação
├── repositories/
│   └── room_repository.dart       # Descoberta e leitura automática de assets/cinemas/
├── theme/
│   └── app_theme.dart             # Tema escuro (Material 3)
├── utils/
│   └── responsive_utils.dart      # Utilitários de responsividade (Mobile/Tablet/Desktop)
├── widgets/
│   └── seat_widget.dart           # Componente visual de cada assento no mapa
└── main.dart                      # Ponto de entrada, Providers e rotas
```

---

## 📚 Documentação Complementar

- [Documentação Técnica Completa](docs/technical_documentation.md)
- [Roadmap — O Que Já Temos vs. Próximas Implementações](docs/roadmap_proximos_passos.md)

---

## 🔧 Como Executar

1. Instale as dependências:
```bash
flutter pub get
```

2. Execute a aplicação:
```bash
flutter run
```
