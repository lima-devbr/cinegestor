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

### 2. Perfis de Acesso (RBAC) e Fluxo de Triagem (*Staging*)
- [x] Modelo de usuário (`AppUser`) com vínculo de unidade (`cinemaId` / `cinemaName`).
- [x] **4 perfis implementados:**
  - **Operação (Limpeza/Portaria):** Abre solicitações rápidas que entram como *Em Triagem* (`staging`).
  - **Assistente de Manutenção:** Abre chamados diretamente como manutenção ativa (`active`).
  - **Encarregado:** Aprova ou recusa solicitações da Triagem e conclui manutenções (`resolved`).
  - **Gerente:** Acesso total (aprova, conclui, reabre chamados e exclui registros).
- [x] Tela exclusiva de **Triagem de Solicitações (`StagingPage`)** com contador de pendências no Lobby.
- [x] Indicação visual no mapa diferenciando assento **Em Triagem** (amarelo/âmbar) de assento **Com Defeito Confirmado** (vermelho).

### 3. Banco de Dados em Nuvem e Segurança Real (Firebase)
- [x] **Projeto Firebase Provisionado (`cinegestor-manutencao`):**
  - Instância **Cloud Firestore** implantada na região `southamerica-east1` (São Paulo, Brasil).
  - Índices compostos implantados (`firestore.indexes.json`) para consultas por `cinemaId`, `status`, `roomId` e `reportedAt`.
- [x] **Firebase Authentication:**
  - Autenticação por E-mail/Senha integrada ao `AuthController` com sincronização de perfis na coleção `/users/{uid}`.
- [x] **Regras de Segurança no Servidor (`firestore.rules`):**
  - Isolamento estrito por unidade (`cinemaId == userCinemaId()`), impedindo que funcionários de outro cinema leiam ou modifiquem dados de outra unidade.
  - Validação no servidor das transições de status por cargo (`operacao`, `assistente`, `encarregado` e `gerente`).
- [x] **Sincronização Híbrida (Nuvem em Tempo Real + Fallback Local):**
  - Stream em tempo real (`snapshots()`) no `RoomController` com cache offline do Firestore e espelhamento em `SharedPreferences`.

### 4. Roteiro de Manutenção por Tipo de Defeito (Tarefas em Lote por Sala)
- [x] **Contadores Rápidos por Tipo de Problema no Lobby:**
  - Exibição direta da quantidade de poltronas com **Capa Rasgada**, **Bracinho Solto**, **Poltrona sem Número**, entre outros defeitos ativos.
- [x] **Tela de Tarefas por Tipo de Defeito (`DefectSummaryPage`):**
  - Filtro rápido por tipo de defeito para que o técnico separe o material necessário (capas, plaquinhas de número, parafusos/braços) de uma só vez.
  - Agrupamento por **Sala** listando exatamente quais assentos possuem cada defeito.
  - Botão de **Conclusão em Lote (`Concluir todos`)** por tarefa dentro da sala, além de conclusão individual por assento.
  - Exportação de **Roteiro de Serviço por Sala** formatado para envio via WhatsApp.

---

## 🚧 Parte 2: O Que Ainda Vamos Implementar (Próximas Etapas)

### Fase 1 — Gestão de Logins, Permissões e Transferência de Cinemas (`UserManagementPage`)
Painel administrativo dentro do próprio aplicativo (acessível pelo perfil **Gerente** e/ou **Supervisor Regional / Admin**) para gerenciar toda a equipe sem precisar abrir o console do Firebase:
- [ ] **Criação de Novos Funcionários (Logins) pelo App:**
  - Formulário para cadastrar **Nome, E-mail, Senha inicial, Cargo (`operacao`, `assistente`, `encarregado`, `gerente`) e Cinema (`cinemaId`)**.
  - Uso de uma **instância secundária do `FirebaseApp`** no momento do `createUserWithEmailAndPassword` para criar a credencial no Firebase Auth e gravar o documento `/users/{uid}` sem deslogar o Gerente atual.
- [ ] **Alteração de Permissões (Promoção / Troca de Cargo em Tempo Real):**
  - Edição rápida do campo `role` do colaborador na coleção `/users/{uid}` (ex.: promover de *Operação* para *Assistente*, ou de *Assistente* para *Encarregado*).
  - Efeito imediato nas regras de segurança (`firestore.rules`), sem necessidade de o funcionário relogar.
- [ ] **Troca de Acesso de Cinemas (Transferência de Unidade e Visão Multi-Cinema):**
  - Atualização dos campos `cinemaId` e `cinemaName` em `/users/{uid}` para transferir um funcionário de uma unidade para outra.
  - Criação de permissão/seletor de unidade para **Gerente / Supervisor Regional**, permitindo alternar entre cinemas da rede e transferir colaboradores entre unidades.
- [ ] **Exclusão e Bloqueio Imediato de Acesso (Desligamento):**
  - Opção para **Desativar (`active: false`)** ou **Excluir** o perfil `/users/{uid}` do colaborador desligado.
  - Bloqueio instantâneo de leitura e escrita pelo `firestore.rules` e bloqueio de login no `AuthController`.
- [ ] **Redefinição de Senha:**
  - Disparo de e-mail de redefinição de senha (`sendPasswordResetEmail`) com 1 toque pelo painel do Gerente ou na tela de login.

### Fase 2 — Expansão Multi-Cinema (Novas Unidades)
- [ ] **Cadastro de Novas Unidades (Múltiplos Cinemas):**
  - Inclusão dos mapas JSON de novas unidades da rede (ex.: *UCI New York City Center*, *UCI Kinoplex NorteShopping*), mantendo isolamento por `cinemaId`.

### Fase 3 — Fotos, Evidências e Melhorias de Campo
- [x] **Anexo de Foto na Abertura e na Conclusão:**
  - Permitir que a Operação/Assistente tire uma foto rápida da poltrona quebrada ao abrir o chamado e que o Encarregado anexe foto do reparo concluído.
- [x] **Histórico Filtrado por Assento / Identificação de Reincidência:**
  - Ao clicar no histórico dentro de uma sala específica, exibir quantas vezes uma mesma poltrona já apresentou defeito no passado.

### Fase 4 — Notificações e Relatórios Gerenciais Avançados
- [ ] **Notificações Push (Firebase Cloud Messaging):**
  - Avisar o Encarregado quando uma nova solicitação entrar na Triagem ou quando um chamado de **Urgência Alta** for aberto.
- [ ] **Dashboard Gerencial e Exportação PDF / Excel (CSV):**
  - Gráficos de tipos de problemas mais frequentes, tempo médio de resolução (SLA) e exportação em PDF/planilha.
