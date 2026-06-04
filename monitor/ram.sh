#!/bin/bash

echo "RAM"
echo "---"
free -h 2>/dev/null || echo "free ist in dieser Umgebung nicht verfügbar"