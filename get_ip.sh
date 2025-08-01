#!/bin/bash
CURRENT_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
echo "Current server IP: $CURRENT_IP"
echo "Server health check:"
curl -s http://$CURRENT_IP:8000/health
echo ""
echo ""
echo "✅ Your iOS app should use: http://$CURRENT_IP:8000"
echo "📱 Update ContentView.swift line 14 if needed"