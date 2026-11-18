# Roadmap do Projeto — O Que Já Temos vs. O Que Falta Implementar

Este documento consolida o estado atual do **CineGestor** e organiza as próximas entregas planejadas para a evolução do sistema em produção.

---

## ✅ Parte 1: O Que Já Está Implementado

### 1. Mapeamento Fiel das Salas (Padrão Ingresso.com)
- [x] Estrutura de diretórios por cinema (`assets/cinemas/uci_park_campo_grande/`).
- [x] Limpeza e padronização das **7 salas reais** do **UCI Park Campo Grande** (`sala_1.json` a `sala_7.json`, totalizando **1.671 assentos**).
- [x] Renderização em matriz (`bounds.lines` × `bounds.columns`) respeitando automaticamente corredores verticais, corredores horizontais, recuos laterais e posição da tela (`stage`).
- [x] Diferenciação visual por tipo de assento: **Normal**, **Cadeirante**, **Acompanhante** e **Obeso**.
- [x] Controles de zoom (`+`, `-`, `Reset`) e legenda fixa no topo do mapa.
- [x] Distinção de impacto operacional: identificação visual de poltronas com **Defeito Bloqueante** (interdita venda de assento, ex: encosto ou assento solto) vs **Defeito Usual** (atenção estética/operacional).

### 2. Perfis de Acesso (RBAC) e Fluxo de Triagem (*Staging*)
- [x] Modelo de usuário (`AppUser`) com vínculo de unidade (`cinemaId` / `cinemaName`).
- [x] **6 perfis implementados:**
  - **Operação (Limpeza/Portaria):** Abre solicitações rápidas que entram como *Em Triagem* (`staging`).
  - **Assistente de Manutenção:** Abre chamados diretamente como manutenção ativa (`active`).
  - **Encarregado:** Aprova ou recusa solicitações da Triagem e conclui manutenções (`resolved`).
  - **Gerente:** Acesso total à unidade (aprova, conclui, reabre chamados, exclui e gerencia equipe local).
  - **Supervisor Regional:** Gestão e acompanhamento global em múltiplas unidades de cinema da rede.
  - **Administrador:** Controle irrestrito do sistema, infraestrutura e publicações de versões.
- [x] Tela exclusiva de **Triagem de Solicitações (`StagingPage`)** com contador de pendências no Lobby.
- [x] Indicação visual no mapa diferenciando assento **Em Triagem** (âmbar) de assento **Com Defeito Confirmado** (vermelho).

### 3. Banco de Dados em Nuvem e Segurança Real (Firebase)
- [x] **Projeto Firebase Provisionado (`cinegestor-manutencao`):**
  - Instância **Cloud Firestore** implantada na região `southamerica-east1` (São Paulo, Brasil).
  - Índices compostos implantados (`firestore.indexes.json`) para consultas por `cinemaId`, `status`, `roomId` e `dateTime`.
- [x] **Firebase Authentication:**
  - Autenticação por E-mail/Senha integrada ao `AuthController` com persistência segura de token.
  - Sincronização de perfis na coleção `/users/{uid}`.
- [x] **Regras de Segurança no Servidor (`firestore.rules`):**
  - Isolamento estrito por unidade (`belongsToCinema(resource.data.cinemaId)`), impedindo vazamento de dados entre cinemas.
  - Validação no servidor das transições de status e campos imutáveis por perfil.
- [x] **Persistência de Login (`AuthGate`):**
  - O usuário permanece conectado mesmo ao fechar e reabrir o app ou navegador. O redirecionamento leva diretamente para as salas sem pedir senha novamente.

### 4. Otimização de Performance e Redução de Custos Diários
- [x] **Stream em Tempo Real Filtrado:** O listener contínuo escuta exclusivamente chamados ativos/triagem (`status in ['staging', 'active']`), economizando até 90% das leituras diárias.
- [x] **Fim de Leituras Duplicadas:** Removido `.get()` redundante na inicialização; o snapshot do Firestore já inicializa o estado de forma atômica.
- [x] **Cache Persistente Local:** Configurado `persistenceEnabled: true` e `CACHE_SIZE_UNLIMITED` para reaproveitar dados em disco (SQLite no Android, IndexedDB na Web).
- [x] **Paginação sob Demanda (`limit: 25`):** Chamados finalizados no histórico são carregados em blocos de 25 registros apenas quando solicitados.
- [x] **Cache em Memória de Configurações:** Verificações de versão têm intervalo de 30 minutos para evitar consultas excessivas em `app_config`.

### 5. Roteiro de Manutenção por Tipo de Defeito (Tarefas em Lote por Sala)
- [x] **Contadores Rápidos por Tipo de Problema no Lobby:**
  - Exibição direta da quantidade de poltronas com **Capa Rasgada**, **PC-E**, **PC-D**, **Poltrona sem Número**, entre outros defeitos ativos.
- [x] **Tela de Tarefas por Tipo de Defeito (`DefectSummaryPage`):**
  - Filtro por tipo de defeito para que o técnico separe o material necessário de uma só vez.
  - Agrupamento por **Sala** listando exatamente quais assentos possuem cada defeito.
  - Botão de **Conclusão em Lote (`Concluir todos`)** por tarefa dentro da sala, além de conclusão individual por assento.
  - Exportação de **Roteiro de Serviço por Sala** formatado para WhatsApp ou prancheta.

### 6. Gestão de Equipe e Logins no Próprio App (`UserManagementPage`)
- [x] **Criação de Usuários sem Deslogar o Gerente:** Uso de instância secundária `FirebaseApp.initializeApp(name: 'UserManagementSecondary')` para criar novos acessos no Firebase Auth sem perder a sessão atual.
- [x] **Gestão de Cargos e Unidades:** Promoção/rebaixamento de cargo e transferência de unidade com sincronização instantânea no Firestore.
- [x] **Bloqueio e Desativação (`active: false`):** Revogação imediata de acesso de funcionários desligados.
- [x] **Primeiro Acesso Obrigatório (`mustChangePassword`):** Força o colaborador a definir uma senha pessoal segura no primeiro login.

### 7. Fotos, Evidências e Reincidência
- [x] **Evidência Fotográfica na Abertura e Conclusão:** Captura de fotos de antes e depois com compressão nativa (JPEG 720px / 55%, ~50 a 80 KB).
- [x] **Compatibilidade Multiplataforma:** Suporte a Câmera/Galeria no Android e seletor nativo HTML5 Canvas na Web.
- [x] **Detecção de Reincidência:** Selo e alerta no histórico informando quantas vezes a mesma poltrona já apresentou problemas anteriores.

### 8. Design System e Distribuição
- [x] **Apple Design System:** Tema Claro (*Light*) e Tema Escuro (*Dark*) refinados, com cantos arredondados contínuos e superfícies translúcidas.
- [x] **Ícone Personalizado:** Logotipo com poltrona estilizada e gradiente grafite sem faixas de cor.
- [x] **Distribuição Web (PWA):** Publicado no Firebase Hosting (`https://cinegestor-manutencao.web.app`).
- [x] **Distribuição Android (In-App Update):** Verificador e instalador silencioso de atualizações APK via Firestore.

---

## 🚧 Parte 2: O Que Ainda Vamos Implementar (Próximas Etapas)

### Fase 1 — Expansão de Novas Unidades da Rede
- [ ] **Mapeamento de Novos Complexos:** Inclusão dos mapas JSON de novos cinemas da rede (ex.: UCI New York City Center, NorteShopping, etc.).
- [ ] **Visão Consolidada Multi-Cinema:** Dashboard comparativo de indicadores entre cinemas para Supervisores e Administradores.

### Fase 2 — Notificações em Tempo Real
- [ ] **Notificações Push (Firebase Cloud Messaging):** Avisar o Encarregado quando um novo chamado urgente for aberto ou quando a Triagem acumular pendências.

### Fase 3 — Relatórios Executivos e Exportação
- [ ] **Exportação em PDF e Excel (CSV):** Geração de relatórios com tempo médio de atendimento (SLA), histórico de custos e peças substituídas.
- [ ] **Gráficos de Tendência:** Relatórios de durabilidade por lote de poltronas ou marcas de revestimento.
