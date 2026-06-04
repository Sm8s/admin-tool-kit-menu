#!/bin/bash

BACKUP_DIR="../backups"

if [ -d "$BACKUP_DIR" ]; then
  echo "Backup-Ordner gefunden:"
  ls -la "$BACKUP_DIR"
else
  echo "Backup-Ordner nicht gefunden."
fi