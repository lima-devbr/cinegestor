# Documentação Técnica — CineGestor

## 1. Visão Geral da Arquitetura

O **CineGestor** segue o padrão **MVC / Provider (ChangeNotifier)** em Flutter, separando responsabilidades entre Modelos de Domínio (`models/`), Repositório de Dados (`repositories/`), Controladores de Estado (`controllers/`), Telas (`pages/`) e Componentes Visuais (`widgets/`).

```text
assets/cinemas/<unidade>/sala_X.json
        │
        ▼
  RoomRepository  ──►  RoomController (ChangeNotifier)  ◄──►  SharedPreferences
                              │
        ┌─────────────────────┼─────────────────────┬─────────────────────┐
        ▼                     ▼                     ▼                     ▼
RoomSelectionPage      MaintenancePage         StagingPage           HistoryPage
```

---

## 2. Modelos de Dados (`lib/models/`)

### 2.1. `AppUser` e `UserRole` (`lib/models/app_user.dart`)
Define os 4 perfis de acesso e suas permissões através de *extension getters*:

| Permissão (Getter) | `operacao` | `assistente` | `encarregado` | `gerente` |
| :--- | :---: | :---: | :---: | :---: |
| `createsAsStaging` | `true` | `false` | `false` | `false` |
| `canApproveStaging` | `false` | `false` | `true` | `true` |
| `canResolveIssue` | `false` | `false` | `true` | `true` |
| `canReopenIssue` | `false` | `false` | `false` | `true` |
| `canDeleteIssue` | `false` | `false` | `false` | `true` |
| `canExportReports` | `false` | `true` | `true` | `true` |

Campos de `AppUser`:
- `id`, `name`, `email`, `password`
- `role` (`UserRole`)
- `cinemaId` (ex.: `"2159"` correspondente ao `theaterBoxOfficeId`)
- `cinemaName` (ex.: `"UCI Park Campo Grande"`)

### 2.2. `MaintenanceIssue` e `IssueStatus` (`lib/models/maintenance_issue.dart`)
Controla o ciclo de vida de uma demanda de manutenção:
- **Estados (`IssueStatus`):**
  - `staging`: Criada pela equipe de Operação; aguarda validação na fila de Triagem.
  - `active`: Problema confirmado (criado pela manutenção ou aprovado na triagem).
  - `resolved`: Manutenção finalizada pelo Encarregado ou Gerente.
  - `rejected`: Solicitação descartada na triagem (duplicada ou improcedente).
- **Campos principais:**
  - `id`: Identificador único composto (`${cinemaId}_${roomId}_${seatId}_${timestamp}`).
  - `cinemaId`, `roomId`, `seatId`.
  - `problemType`, `urgency` (`Baixa`, `Média`, `Alta`), `notes`.
  - `dateTime`, `reportedBy`, `reportedRole`.
  - `resolvedAt`, `resolvedBy`, `rejectionReason`.

### 2.3. `Room` e `GridLabel` (`lib/models/room.dart`)
Suporta tanto o formato legado quanto o **formato de matriz (Grid)** extraído da Ingresso.com:
- `id`, `nome`, `theaterId`, `theaterName`.
- `displayName`: Retorna o nome abreviado da unidade junto à sala (ex.: `"UCI Park CG • Sala 4"`).
- `boundsLines` e `boundsColumns`: Dimensões da matriz da sala.
- `gridLabels`: Posições `(line, column)` das letras identificadoras de fileira nos dois lados da sala.
- `stageLine`: Linha da matriz onde fica a tela (`TELA`).
- `seats`: Mapa `Map<String, Seat>` indexado pelo código do assento (ex.: `"D10"`).

### 2.4. `Seat` (`lib/models/seat.dart`)
Representa cada cadeira física da sala:
- `row` (letra da fileira em maiúsculo) e `number` (número do assento).
- `line` e `column`: Coordenadas exatas dentro da matriz `bounds`.
- `type`: `'Regular'` (Normal), `'Disability'` (Cadeirante), `'Companion'` (Acompanhante), `'Obese'` (Obeso).
- `hasDefect`: `true` quando há pelo menos uma `MaintenanceIssue` com `status == IssueStatus.active` para o assento.
- `hasStaging`: `true` quando há pelo menos uma `MaintenanceIssue` com `status == IssueStatus.staging` para o assento.

---

## 3. Formato de JSON das Salas (`assets/cinemas/`)

Os arquivos em `assets/cinemas/<slug_do_cinema>/sala_X.json` seguem uma estrutura limpa derivada da Ingresso.com:

```json
{
  "id": "4",
  "theaterBoxOfficeId": "2159",
  "theaterName": "UCI Park Campo Grande",
  "theaterLocationBoxOfficeId": "2162",
  "theaterLocationName": "Sala 4",
  "totalSeats": 319,
  "bounds": { "lines": 22, "columns": 31 },
  "stage": {
    "upperLeft": { "line": 21, "column": 1 },
    "lowerRight": { "line": 21, "column": 30 }
  },
  "labels": [
    { "label": "P", "line": 2, "column": 1 },
    { "label": "P", "line": 2, "column": 30 }
  ],
  "lines": [
    {
      "line": 2,
      "seats": [
        {
          "label": "P1",
          "row": "P",
          "number": 1,
          "line": 2,
          "column": 2,
          "type": "Regular"
        }
      ]
    }
  ]
}
```

---

## 4. Fluxo de Navegação e Rotas (`lib/main.dart`)

- `/`: `LoginPage` — Autenticação e seleção rápida de perfil de teste.
- `/rooms`: `RoomSelectionPage` — Painel da unidade, indicadores gerais e cards das salas.
- `/maintenance`: `MaintenancePage` — Mapa em grid com zoom/pan, detalhes do assento e abertura/resolução de problemas.
- `/staging`: `StagingPage` — Fila de aprovação/rejeição das solicitações enviadas pela Operação.
- `/history`: `HistoryPage` — Histórico completo com filtros, ações baseadas no cargo e exportação de relatório.
