# Simple deployment script - Run all commands in sequence
Write-Host "Starting deployment..." -ForegroundColor Green

# 1. Create namespace
Write-Host "1. Creating namespace..." -ForegroundColor Yellow
kubectl apply -f namespace.yml

# 2. Create MongoDB PV and PVC
Write-Host "2. Creating MongoDB PV and PVC..." -ForegroundColor Yellow
kubectl apply -f mongodb-pv.yml
kubectl apply -f mongodb-pvc.yml

# 3. Create MongoDB Secret
Write-Host "3. Creating MongoDB Secret..." -ForegroundColor Yellow
kubectl apply -f mongodb-secret.yml

# 4. Deploy MongoDB Service first
Write-Host "4. Deploying MongoDB Service..." -ForegroundColor Yellow
kubectl apply -f mongodb-service.yml

# 5. Deploy MongoDB Deployment
Write-Host "5. Deploying MongoDB..." -ForegroundColor Yellow
kubectl apply -f mongodb-deployment.yml

# 6. Wait for MongoDB to be ready
Write-Host "6. Waiting for MongoDB to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=mongodb -n chat-app --timeout=120s

# 7. Create Backend Config and Secret
Write-Host "7. Creating Backend Config and Secret..." -ForegroundColor Yellow
kubectl apply -f backend-configmap.yml
kubectl apply -f backend-secret.yml

# 8. Deploy Backend Service
Write-Host "8. Deploying Backend Service..." -ForegroundColor Yellow
kubectl apply -f backend-service.yml

# 9. Deploy Backend Deployment
Write-Host "9. Deploying Backend..." -ForegroundColor Yellow
kubectl apply -f backend-deployment.yml

# 10. Create Frontend Config
Write-Host "10. Creating Frontend Config..." -ForegroundColor Yellow
kubectl apply -f frontend-configmap.yml

# 11. Deploy Frontend Service
Write-Host "11. Deploying Frontend Service..." -ForegroundColor Yellow
kubectl apply -f frontend-service.yml

# 12. Deploy Frontend Deployment
Write-Host "12. Deploying Frontend..." -ForegroundColor Yellow
kubectl apply -f frontend-deployment.yml

# 13. Check status
Write-Host "`nDeployment completed! Checking status..." -ForegroundColor Green
kubectl get pods -n chat-app
Write-Host ""
kubectl get svc -n chat-app
Write-Host ""

# 14. Get access URL
Write-Host "Access Information:" -ForegroundColor Cyan
$ip = minikube ip
Write-Host "Frontend URL: http://$ip:30080" -ForegroundColor Cyan
