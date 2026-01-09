# Diagnostic script to check why pods aren't running
Write-Host "=== Pod Diagnostic Script ===" -ForegroundColor Green
Write-Host ""

# Check cluster connection
Write-Host "1. Checking cluster connection..." -ForegroundColor Yellow
kubectl cluster-info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Cannot connect to cluster!" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and then run: minikube start" -ForegroundColor Yellow
    exit 1
}
Write-Host "Cluster is accessible." -ForegroundColor Green
Write-Host ""

# Check namespace
Write-Host "2. Checking namespace..." -ForegroundColor Yellow
kubectl get namespace chat-app 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Namespace 'chat-app' does not exist!" -ForegroundColor Red
    Write-Host "Run: kubectl apply -f namespace.yml" -ForegroundColor Yellow
} else {
    Write-Host "Namespace exists." -ForegroundColor Green
}
Write-Host ""

# Check all pods
Write-Host "3. Checking pod status..." -ForegroundColor Yellow
kubectl get pods -n chat-app
Write-Host ""

# Get pod details
Write-Host "4. Detailed pod information:" -ForegroundColor Yellow
$pods = kubectl get pods -n chat-app -o json | ConvertFrom-Json

if ($pods.items.Count -eq 0) {
    Write-Host "No pods found in namespace!" -ForegroundColor Red
    Write-Host "Please deploy resources first using deploy.ps1 or deploy.txt" -ForegroundColor Yellow
    exit 1
}

foreach ($pod in $pods.items) {
    $podName = $pod.metadata.name
    $status = $pod.status.phase
    $ready = $pod.status.containerStatuses[0].ready
    
    Write-Host "`n=== Pod: $podName ===" -ForegroundColor Cyan
    Write-Host "Status: $status" -ForegroundColor $(if ($status -eq "Running") { "Green" } else { "Red" })
    Write-Host "Ready: $ready" -ForegroundColor $(if ($ready) { "Green" } else { "Red" })
    
    # Check container status
    if ($pod.status.containerStatuses) {
        foreach ($container in $pod.status.containerStatuses) {
            if ($container.state.waiting) {
                Write-Host "Waiting reason: $($container.state.waiting.reason)" -ForegroundColor Yellow
                Write-Host "Waiting message: $($container.state.waiting.message)" -ForegroundColor Yellow
            }
            if ($container.state.terminated) {
                Write-Host "Terminated reason: $($container.state.terminated.reason)" -ForegroundColor Red
                Write-Host "Exit code: $($container.state.terminated.exitCode)" -ForegroundColor Red
            }
        }
    }
    
    # Check events
    Write-Host "`nRecent Events:" -ForegroundColor Yellow
    kubectl get events -n chat-app --field-selector involvedObject.name=$podName --sort-by='.lastTimestamp' | Select-Object -Last 5
    
    # Check logs if pod is not running
    if ($status -ne "Running" -or -not $ready) {
        Write-Host "`nPod Logs (last 20 lines):" -ForegroundColor Yellow
        kubectl logs $podName -n chat-app --tail=20 2>&1
    }
}

Write-Host "`n5. Checking PVC status..." -ForegroundColor Yellow
kubectl get pvc -n chat-app
Write-Host ""

Write-Host "6. Checking PV status..." -ForegroundColor Yellow
kubectl get pv mongodb-pv 2>&1
Write-Host ""

Write-Host "7. Checking Services..." -ForegroundColor Yellow
kubectl get svc -n chat-app
Write-Host ""

Write-Host "8. Checking ConfigMaps and Secrets..." -ForegroundColor Yellow
kubectl get configmap -n chat-app
kubectl get secret -n chat-app
Write-Host ""

Write-Host "=== Common Issues ===" -ForegroundColor Green
Write-Host "1. ImagePullError: Docker images not found. Pull images first or check image names."
Write-Host "2. ImagePullBackOff: Check Docker Hub credentials or image availability."
Write-Host "3. Pending: Check PVC binding and node resources."
Write-Host "4. CrashLoopBackOff: Check logs above for application errors."
Write-Host "5. ErrImagePull: Image doesn't exist or no access. Check imagePullPolicy."
