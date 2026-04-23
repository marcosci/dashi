# ADR-004 — Punktwolkenformat: COPC

**Status:** ✅ Entschieden

## Kontext

Punktwolkendaten (LiDAR, UAV-Scans) müssen cloud-nativ speicher- und abfragbar sein.

## Bewertete Alternativen

| Alternative                  | Vorteile | Nachteile |
|------------------------------|----------|-----------|
| **COPC (Cloud Optimized Point Cloud)** | LAZ-basiert, räumlich indiziert, cloud-nativ | Noch nicht überall unterstützt |
| LAZ / LAS                    | Weit verbreitet, komprimiert | Nicht cloud-nativ |
| EPT (Entwine Point Tiles)    | Cloud-nativ, Potree-kompatibel | Proprietärer Charakter, geringere Verbreitung |

## Entscheidung

**COPC** als primäres Punktwolkenformat.

## Konsequenzen

- LAS/LAZ-Eingangsdaten werden beim Übergang Landing → Processed nach COPC konvertiert
- Räumliche Indizierung ist im Format inhärent enthalten
