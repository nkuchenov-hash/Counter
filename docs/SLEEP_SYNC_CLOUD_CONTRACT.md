# Sleep synchronization cloud contract

- Ingestion is server-only. LIFE OS clients never depend on Health Connect or any device-local health store.
- The canonical client-visible data is PocketBase `records`.
- Recent sleep is read from Google Health API `sleep` reconciled `all-sources` data.
- Existing Google Fit-derived records remain canonical history during the transition away from legacy Fit REST.
- The user sees one setting only: Sleep synchronization.
- OAuth is one consent flow and requests read-only sleep access only.
- A sleep record contains only the asleep-to-awake interval; sleep stages and other health metrics are not persisted by this feature.
