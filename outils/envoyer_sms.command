#!/bin/bash
# Envoi des SMS préparés par le site de l'Ecole de Musique de Ceyreste,
# depuis l'application Messages du Mac (les SMS partent de votre iPhone/forfait).
#
# Utilisation : double-clic, ou dans le Terminal :  bash envoyer_sms.command [fichier.tsv]
# Sans fichier indiqué, prend le dernier « sms_a_envoyer….tsv » du dossier Téléchargements.
# Format du fichier (une ligne par SMS) : numéro <tab> nom <tab> message

FICHIER="${1:-}"
if [ -z "$FICHIER" ]; then
  FICHIER=$(ls -t "$HOME/Downloads"/sms_a_envoyer*.tsv 2>/dev/null | head -1)
fi
if [ ! -f "$FICHIER" ]; then
  echo "Aucun fichier sms_a_envoyer….tsv trouvé dans Téléchargements."
  echo "Préparez-le d'abord depuis le site (bouton « SMS groupés »)."
  read -r -p "Appuyez sur Entrée pour fermer." _
  exit 1
fi

N=$(grep -c . "$FICHIER")
echo "Fichier : $FICHIER"
echo "$N SMS à envoyer :"
echo
while IFS=$'\t' read -r num nom msg; do
  [ -n "$num" ] && printf '  %-14s %s\n' "$num" "$nom"
done < "$FICHIER"
echo
printf 'Exemple de message :\n  %s\n\n' "$(head -1 "$FICHIER" | cut -f3-)"
if [ "${ENVOI_CONFIRME:-}" != "oui" ]; then
  read -r -p "Envoyer ces $N SMS maintenant ? Tapez oui pour confirmer : " rep
  if [ "$rep" != "oui" ]; then echo "Annulé : rien n'a été envoyé."; exit 0; fi
fi

ok=0; ko=0
JOURNAL="${FICHIER%.tsv}_journal.txt"
while IFS=$'\t' read -r num nom msg; do
  [ -z "$num" ] && continue
  if osascript - "$num" "$msg" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
	set num to item 1 of argv
	set msg to item 2 of argv
	tell application "Messages"
		try
			set svc to 1st account whose service type = SMS
			send msg to participant num of svc
		on error
			try
				set svc to 1st account whose service type = iMessage
				send msg to participant num of svc
			on error
				set svc to 1st service whose service type = iMessage
				send msg to buddy num of svc
			end try
		end try
	end tell
end run
APPLESCRIPT
  then ok=$((ok+1)); echo "✓ $num  $nom" | tee -a "$JOURNAL"
  else ko=$((ko+1)); echo "✗ $num  $nom  (échec)" | tee -a "$JOURNAL"
  fi
  sleep 1
done < "$FICHIER"

echo
echo "Terminé : $ok envoyé(s), $ko échec(s). Journal : $JOURNAL"
[ "${ENVOI_CONFIRME:-}" = "oui" ] || read -r -p "Appuyez sur Entrée pour fermer." _
