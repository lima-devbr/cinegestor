# Roadmap do Projeto — O Que Já Temos vs. O Que Falta Implementar

Este documento consolida o estado atual do **CineGestor (MVP Concluído)** e organiza as próximas entregas planejadas para a evolução do sistema em produção.

---

## ✅ Parte 1: O Que Já Está Implementado (MVP Atual)

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
- [x] Persistência local de sessão do usuário logado (`SharedPreferences`).

### 3. Gestão, Histórico e Relatórios
- [x] Mini-dashboard no topo do Lobby (`Salas`, `% Operacionais`, `Manutenção Ativa` e `Em Triagem`).
- [x] Sincronização automática do estado das cadeiras com os chamados salvos localmente.
- [x] Resolução rápida de chamados direto pela tela do mapa ao clicar em um assento defeituoso.
- [x] Histórico com filtros combinados por **Sala**, **Status** (*Todos, Em Triagem, Em Manutenção, Resolvidos*) e **Urgência** (*Alta, Média, Baixa*).
- [x] Exportação e cópia de relatório formatado para a área de transferência (para envio via WhatsApp/e-mail).

---

## 🚧 Parte 2: O Que Ainda Vamos Implementar (Próximas Etapas)

### Fase 1 — Backend em Nuvem e Segurança Real (Prioridade Alta)
Hoje os dados ficam salvos localmente em cada aparelho (`SharedPreferences`). Para que a solicitação aberta pela **Operação** apareça instantaneamente no celular do **Encarregado** e do **Gerente**:
- [ ] **Banco de Dados em Tempo Real (Firebase Firestore ou Supabase):**
  - Sincronização em tempo real das coleções `users`, `cinemas`, `rooms` e `maintenance_issues`.
- [ ] **Autenticação Real (Firebase Auth ou Supabase Auth):**
  - Login real por e-mail/senha gerenciado no servidor.
- [ ] **Regras de Segurança no Servidor (Security Rules / Row Level Security):**
  - Garantir no banco de dados que funcionários de um `cinemaId` **nunca** consigam consultar ou alterar dados de outro cinema.
  - Garantir no servidor que apenas `encarregado` e `gerente` possam aprovar triagem ou concluir manutenção, e apenas `gerente` possa excluir.

### Fase 2 — Gestão Multi-Cinema e Administração de Equipe
- [ ] **Cadastro de Novas Unidades (Múltiplos Cinemas):**
  - Suporte a múltiplas pastas/unidades (ex.: *UCI New York City Center*, *UCI Kinoplex NorteShopping*), com chave composta `${cinemaId}_${roomId}` em todas as consultas.
  - Seletor de unidade para usuários com perfil de **Gerente Regional / Admin**.
- [ ] **Tela de Gestão de Funcionários (Exclusiva do Gerente):**
  - Cadastrar novos funcionários do seu cinema, definir o cargo (*Operação, Assistente, Encarregado*) e desativar acessos de ex-funcionários.

### Fase 3 — Fotos, Evidências e Melhorias de Campo
- [ ] **Anexo de Foto na Abertura e na Conclusão:**
  - Permitir que a Operação/Assistente tire uma foto rápida da poltrona quebrada ao abrir o chamado e que o Encarregado anexe foto do reparo concluído.
- [ ] **Modo Offline-First com Sincronização Automática:**
  - Como salas de cinema costumam ter sinal fraco de Wi-Fi/4G, permitir registrar o chamado offline e sincronizar automaticamente com a nuvem assim que o funcionário sair para o lobby.
- [ ] **Histórico Filtrado por Assento / Sala Direto do Mapa:**
  - Ao clicar no botão de histórico dentro de uma sala específica, abrir o histórico já pré-filtrado naquela sala, exibindo inclusive quantas vezes aquela mesma cadeira já deu defeito no passado (identificação de poltronas reincidentes).

### Fase 4 — Notificações e Relatórios Avançados
- [ ] **Notificações Push:**
  - Avisar o Encarregado quando uma nova solicitação entrar na Triagem ou quando um chamado de **Urgência Alta** for aberto.
- [ ] **Dashboard Gerencial e Exportação PDF / Excel (CSV):**
  - Gráficos de tipos de problemas mais frequentes (ex.: *Trocar Mola*, *Couro Rasgado*, *Não Reclina*), tempo médio de resolução (SLA) e exportação em PDF/planilha.
