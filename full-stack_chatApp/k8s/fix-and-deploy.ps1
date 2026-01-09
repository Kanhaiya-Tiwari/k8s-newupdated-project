# Complete fix and deployment script
Write-Host "=== Chat App Deployment Fix ===" -ForegroundColor Green
Write-Host ""

# Step 1: Check Docker
Write-Host "Step 1: Checking Docker..." -ForegroundColor Yellow
$dockerStatus = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker is not running!" -ForegroundColor Red
    Write-Host "Please start Docker Desktop first, then run this script again." -ForegroundColor Yellow
    exit 1
}
Write-Host "Docker is running." -ForegroundColor Green
Write-Host ""

# Step 2: Start Minikube
Write-Host "Step 2: Starting Minikube..." -ForegroundColor Yellow
minikube status | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Minikube is not running. Starting..." -ForegroundColor Yellow
    minikube start
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to start minikube!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Minikube is already running." -ForegroundColor Green
}
Write-Host ""

# Step 3: Create MongoDB directory
Write-Host "Step 3: Creating MongoDB data directory..." -ForegroundColor Yellow
minikube ssh "sudo mkdir -p /data/mongodb && sudo chmod 777 /data/mongodb" 2>&1 | Out-Null
Write-Host "MongoDB directory created." -ForegroundColor Green
Write-Host ""

# Step 4: Navigate to k8s directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

# Step 5: Delete existing resources if any (to start fresh)
Write-Host "Step 4: Cleaning up existing resources..." -ForegroundColor Yellow
kubectl delete namespace chat-app --ignore-not-found=true 2>&1 | Out-Null
kubectl delete pv mongodb-pv --ignore-not-found=true 2>&1 | Out-Null
Write-Host "Cleanup completed." -ForegroundColor Green
Write-Host ""

# Step 6: Deploy in correct order
Write-Host "Step 5: Deploying resources..." -ForegroundColor Yellow

Write-Host "  Creating namespace..." -ForegroundColor Cyan
kubectl apply -f namespace.yml
Start-Sleep -Seconds 2

Write-Host "  Creating MongoDB PV and PVC..." -ForegroundColor Cyan
kubectl apply -f mongodb-pv.yml
kubectl apply -f mongodb-pvc.yml
Start-Sleep -Seconds 2

Write-Host "  Creating MongoDB Secret..." -ForegroundColor Cyan
kubectl apply -f mongodb-secret.yml
Start-Sleep -Seconds 2

Write-Host "  Deploying MongoDB Service..." -ForegroundColor Cyan
kubectl apply -f mongodb-service.yml
Start-Sleep -Seconds 2

Write-Host "  Deploying MongoDB..." -ForegroundColor Cyan
kubectl apply -f mongodb-deployment.yml
Write-Host "  Waiting for MongoDB pod..." -ForegroundColor Cyan
kubectl wait --for=condition=ready pod -l app=mongodb -n chat-app --timeout=180s 2>&1 | Out-Null

Write-Host "  Creating Backend Config and Secret..." -ForegroundColor Cyan
kubectl apply -f backend-configmap.yml
kubectl apply -f backend-secret.yml
Start-Sleep -Seconds 2

Write-Host "  Deploying Backend Service..." -ForegroundColor Cyan
kubectl apply -f backend-service.yml
Start-Sleep -Seconds 2

Write-Host "  Deploying Backend..." -ForegroundColor Cyan
kubectl apply -f backend-deployment.yml
Start-Sleep -Seconds 2

Write-Host "  Creating Frontend Config..." -ForegroundColor Cyan
kubectl apply -f frontend-configmap.yml
Start-Sleep -Seconds 2

Write-Host "  Deploying Frontend Service..." -ForegroundColor Cyan
kubectl apply -f frontend-service.yml
Start-Sleep -Seconds 2

Write-Host "  Deploying Frontend..." -ForegroundColor Cyan
kubectl apply -f frontend-deployment.yml
Write-Host ""

# Step 7: Check pod status and diagnose issues
Write-Host "Step 6: Checking pod status..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
kubectl get pods -n chat-app
Write-Host ""

# Step 8: Show pod details if not running
Write-Host "Pod Details:" -ForegroundColor Yellow
$pods = kubectl get pods -n chat-app -o json | ConvertFrom-Json
foreach ($pod in $pods.items) {
    $status = $pod.status.phase
    if ($status -ne "Running") {
        Write-Host "`nPod: $($pod.metadata.name) - Status: $status" -ForegroundColor Red
        Write-Host "Checking events..." -ForegroundColor Yellow
        kubectl describe pod $($pod.metadata.name) -n chat-app | Select-String -Pattern "Events:|Warning:|Error:" -Context 0,3
        Write-Host "Checking logs..." -ForegroundColor Yellow
        kubectl logs $($pod.metadata.name) -n chat-app --tail=20 2>&1
    }
}
Write-Host ""

# Step 9: Final status
Write-Host "=== Final Status ===" -ForegroundColor Green
kubectl get pods -n chat-app
kubectl get svc -n chat-app
kubectl get pvc -n chat-app
Write-Host ""

# Step 10: Access information
$ip = minikube ip
Write-Host "Access Information:" -ForegroundColor Cyan
Write-Host "  Frontend URL: http://$ip:30080" -ForegroundColor White
Write-Host "  Minikube IP: $ip" -ForegroundColor White
Write-Host ""

Write-Host "Deployment completed!" -ForegroundColor Green
