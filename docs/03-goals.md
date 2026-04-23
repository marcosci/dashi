# 3. Ziele & Nicht-Ziele

## Ziele

Die folgenden Ziele definieren den Erfolg dieser Initiative. Sie sind bewusst messbar formuliert, um als Grundlage für Abnahmekriterien und Phasenbewertungen zu dienen.

### Architektonische Ziele

- Aufbau einer einheitlichen, cloud-nativen Speicher- und Verarbeitungsplattform für alle organisationsrelevanten Geodatenbestände
- Etablierung eines verbindlichen Zonenmodells (Landing → Processed → Curated) mit definierten Übergabeverträgen zwischen den Schichten
- Einführung eines einheitlichen Koordinatenreferenzsystems als organisationsweiten Standard, durchgesetzt an den Zonengrenzen der Pipeline
- Implementierung eines räumlich-zeitlichen Datenkatalogs, der alle Datensätze auffindbar, beschreibbar und abonnierbar macht

### Operative Ziele

- Konsolidierung der Geodaten aus den vier Domänen Aufklärung & ISR, Missionsplanung & C2, Logistik & Versorgung sowie Gelände & Umwelt unter einer gemeinsamen Plattform
- Reduktion manueller Datenaufbereitungsaufwände um mindestens **[X %]** innerhalb der ersten zwölf Monate nach Produktivbetrieb
- Bereitstellung nachvollziehbarer, versionierter und wiederholbarer Analyseprodukte für alle angebundenen Konsumententeams
- Schaffung der technischen Voraussetzungen für KI/ML-gestützte Auswerteverfahren auf Geodaten

### Governance-Ziele

- Definition klarer Dateneigentümerschaft für jeden Datensatz und jede Domäne
- Einführung verbindlicher Qualitätsstandards und Metadatenanforderungen als Voraussetzung für die Aufnahme in die Plattform
- Lückenlose Nachvollziehbarkeit der Datenherkunft und Verarbeitungshistorie für alle produktiven Datenpipelines

## Nicht-Ziele

Diese Punkte sind bewusst aus dem Scope ausgeschlossen. Sie werden hier explizit benannt, um Erwartungen zu steuern und Scope Creep frühzeitig zu verhindern.

**Der Spatial Data Lake ist kein Echtzeit-Gefechtsinformationssystem.**
Die Plattform ist auf analytische und planerische Workloads ausgelegt. Echtzeit-Datenströme mit taktischen Latenzanforderungen im Millisekundenbereich sind kein Ziel dieser Initiative und erfordern eine gesonderte Architektur.

**Die Plattform ersetzt keine bestehenden Führungsinformationssysteme (FüInfoSys).**
Bestehende operative Systeme bleiben in ihrer Funktion unberührt. Der Data Lake ergänzt diese Systeme als analytische Schicht — er löst sie nicht ab und greift nicht in ihre Prozesse ein.

**Visualisierung und Kartendarstellung sind kein Bestandteil dieser Initiative.**
Der Data Lake liefert Daten und Schnittstellen. Die Entwicklung von GIS-Clients, Kartenanwendungen oder Dashboards liegt außerhalb des Scopes und obliegt den jeweiligen Konsumententeams oder nachgelagerten Projekten.

**Die Plattform übernimmt keine Verantwortung für die Qualität von Quelldaten.**
Qualitätssicherung beginnt an der Grenze zwischen Landing Zone und Processed Zone. Für die inhaltliche Korrektheit von Daten, die von Quellsystemen geliefert werden, tragen die jeweiligen Datenlieferanten die Verantwortung.

**Migration historischer Altdatenbestände ist nicht Teil von Phase 1 und 2.**
Die Überführung bestehender Datenarchive in die neue Plattform wird als separates Vorhaben betrachtet und ist nicht Bestandteil des initialen Lieferumfangs.

**Der Betrieb von Klassifizierungsstufen oberhalb von [X] ist nicht Gegenstand dieser Initiative.**
Anforderungen an den Betrieb von Daten höherer Geheimhaltungsstufen erfordern gesonderte Sicherheitsarchitektur, Akkreditierungsprozesse und Infrastruktur und werden in einem separaten Vorhaben adressiert.
