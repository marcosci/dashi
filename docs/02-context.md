# 2. Kontext & Motivation

## Warum jetzt?

Die Anforderungen an geospatiale Informationen im militärischen Umfeld wachsen schneller als die bestehende Infrastruktur mithalten kann. Drei Entwicklungen machen ein Handeln zum jetzigen Zeitpunkt notwendig:

**Volumen und Vielfalt verfügbarer Geodaten** steigen exponentiell — durch kommerzielle Satellitenkonstellationen, UAV-gestützte Aufklärung, IoT-Sensornetzwerke und offene Geländedatenquellen. Ohne eine strukturierte Plattform können diese Daten nicht systematisch genutzt werden.

**KI- und ML-gestützte Lageauswertung** rückt in den operativen Fokus moderner Streitkräfte. Diese Fähigkeiten setzen eine konsolidierte, saubere und historisch tiefe Datenbasis voraus — eine Voraussetzung, die mit der aktuellen Silostruktur nicht erfüllbar ist.

**Zunehmender Einsatz verbündeter und multinationaler Kräfte** erzeugt wachsende Anforderungen an Interoperabilität und gemeinsame Lagedaten. Eine standardisierte Geodatenarchitektur ist die technische Grundlage dafür.

## Was ist heute kaputt oder fehlt?

Die aktuelle Situation ist durch mehrere strukturelle Schwachstellen gekennzeichnet:

- **Datenfragmentierung** — Geodaten liegen in unterschiedlichen Systemen, bei unterschiedlichen Teileinheiten und in unterschiedlichen Formaten vor. Es existiert keine einheitliche Übersicht darüber, welche Daten in welcher Qualität wo verfügbar sind. Wer Daten benötigt, muss sie manuell anfragen, konvertieren und validieren.

- **Fehlende Nachvollziehbarkeit** — Die Herkunft und Verarbeitungshistorie von Datenprodukten ist in der Regel nicht dokumentiert. Ob ein Geländemodell aktuell ist, aus welcher Quelle es stammt und welche Transformationen es durchlaufen hat, ist nicht zuverlässig feststellbar. Das untergräbt das Vertrauen in die Daten — und damit in die darauf basierenden Entscheidungen.

- **Redundante Arbeitsaufwände** — Dieselben Datensätze werden in mehreren Teams unabhängig voneinander beschafft, aufbereitet und vorgehalten. Das bindet Kapazitäten, die für analytische Arbeit fehlen.

- **Keine domänenübergreifende Fusion** — Aufklärungsdaten, Geländeinformationen, Logistiklagen und C2-relevante Geodaten werden nicht systematisch zusammengeführt. Querbeziehungen, die operativ relevant wären, bleiben unsichtbar — nicht weil sie nicht existieren, sondern weil die technische Grundlage für ihre Verknüpfung fehlt.

- **Fehlende Skalierbarkeit** — Bestehende Lösungen wurden für den heutigen Datenumfang gebaut. Sie sind weder technisch noch organisatorisch darauf ausgelegt, das künftige Datenvolumen zu bewältigen.

## Welche Fähigkeiten werden durch diese Initiative freigeschaltet?

Ein Spatial Data Lake als gemeinsame Plattform schafft Voraussetzungen, die heute strukturell nicht möglich sind:

- **Domänenübergreifende Lagebilder** — Aufklärung, Gelände, Logistik und Führungsinformationen können räumlich und zeitlich verknüpft und gemeinsam ausgewertet werden
- **Reproduzierbare Analyseprodukte** — Jedes Produkt ist auf seine Quelldaten und Verarbeitungsschritte zurückverfolgbar, validierbar und wiederholbar
- **Beschleunigte Produktionsketten** — Standardisierte Pipelines ersetzen manuelle Aufbereitungsprozesse und verkürzen die Zeit vom Rohdatum zum einsatzbereiten Produkt erheblich
- **Fundament für KI/ML-Anwendungen** — Historisch tiefe, qualitätsgesicherte und einheitlich strukturierte Geodaten sind die Voraussetzung für maschinelles Lernen auf operativ relevanten Fragestellungen
- **Interoperabilität** — Standardisierte Formate und Schnittstellen ermöglichen den Datenaustausch mit Bündnispartnern und anderen Systemen ohne manuelle Zwischenschritte
