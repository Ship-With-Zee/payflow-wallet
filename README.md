# PayFlow - Production-Grade FinTech Platform

**Enterprise patterns for DevOps portfolios**

## 🎓 **NEW TO THIS PROJECT? START HERE!**

👉 **[Complete Learning Path Guide](docs/LEARNING-PATH.md)** - Step-by-step guide from beginner to production

**This project is intentionally complex (production-grade), but we've created a learning path to make it manageable:**

- **Stage 1**: Learn locally with Docker Compose ($0)
- **Stage 2**: Deploy to one cloud provider (~$200/month)
- **Stage 3**: Add production patterns (~$300/month)
- **Stage 4**: Master advanced topics (~$500+/month)

**Also check out:**
- [Simplified Configuration Guide](docs/SIMPLIFIED-CONFIG.md) - How to disable complex features for learning

---

## 🎯 What You'll Build
- Hub-spoke VPC architecture ($175/month)
- Private EKS cluster with Multi-AZ HA
- **RDS PostgreSQL** (Multi-AZ for production, Single-AZ for dev)
- **ElastiCache Redis** (Cluster with failover for production)
- Microservices application (6 services)
- Full observability stack (Prometheus, Grafana, **CloudWatch alarms**)
- CI/CD pipeline with GitOps

**Total Cost:** $530/month (all environments) | **Time:** 3-4 hours | **Level:** Intermediate

**For Learning:** Start with [Simplified Config](docs/SIMPLIFIED-CONFIG.md) to reduce cost to ~$200/month

## 🚀 Quick Start

**New here? Follow the learning path:**
1. **[Learning Path Guide](docs/LEARNING-PATH.md)** - Complete beginner guide
2. [Start Here - 5 min read](docs/AWS/00-START-HERE.md) - AWS-specific quick start
3. [Prerequisites - 15 min setup](docs/AWS/01-PREREQUISITES.md)
4. [Understand Architecture - 30 min](docs/AWS/02-UNDERSTAND-FIRST.md)
5. [Deploy Infrastructure - 2 hours](docs/AWS/03-DEPLOY-HUB.md)

**Already know what you're doing?**
```bash
cd terraform/environments/hub && terraform apply
cd ../production && terraform apply
kubectl apply -k k8s/
```

## 📚 Documentation

### 🎓 Learning Resources
- **[Learning Path Guide](docs/LEARNING-PATH.md)** ⭐ **START HERE** - Complete beginner-to-advanced guide
- **[Simplified Configuration](docs/SIMPLIFIED-CONFIG.md)** - How to disable complex features for learning

### AWS Deployment
- [Start Here](docs/AWS/00-START-HERE.md) - Quick start guide
- [Architecture Overview](docs/AWS/ARCHITECTURE.md) - Hub-spoke design, RDS, ElastiCache
- [Production Deployment](docs/AWS/04-DEPLOY-PRODUCTION.md) - Deploy with RDS and Redis
- [Cost Optimization](docs/AWS/COST-OPTIMIZATION.md) - Complete cost breakdown
- [Troubleshooting](docs/AWS/TROUBLESHOOTING.md) - Common issues and solutions
- [Interview Prep](docs/AWS/INTERVIEW-GUIDE.md) - Talking points and metrics

### Azure Deployment
- [Azure Deployment Guide](docs/AZURE/COMPLETE-DEPLOYMENT-GUIDE.md) - Complete Azure infrastructure setup
- [Secondary Region & Resource Locks](docs/AZURE/SECONDARY-REGION-AND-LOCKS.md) - Enable disaster recovery and resource protection
- [Self-Hosted Runners](docs/AZURE/SELF-HOSTED-RUNNERS.md) - Setup GitHub Actions runners for Terraform deployment
- **Note**: Secondary region is **disabled by default** to save costs (~$280-810/month). The infrastructure was deployed without secondary region for cost optimization during development. If you need disaster recovery, you can enable it by setting `enable_secondary_region = true` in `terraform.tfvars`. See [Secondary Region Guide](docs/AZURE/SECONDARY-REGION-AND-LOCKS.md) for detailed instructions.

### Local Development
- [Local Deployment](docs/LOCAL/) - MicroK8s, Docker Compose, K3d

## 🎓 Learning Outcomes

After completing this project, you'll be able to:
- Explain hub-spoke VPC patterns in interviews ✅
- Deploy production-grade Kubernetes on AWS ✅
- Justify infrastructure cost decisions ✅
- Implement GitOps with ArgoCD ✅

## 💼 Interview Talking Points

This project demonstrates:
- **Multi-AZ high availability** (RDS Multi-AZ, Redis cluster, EKS Multi-AZ)
- **Cost optimization** ($930/month → $530/month with all environments)
- **Security defense-in-depth** (7 layers, private endpoints, VPC isolation)
- **Infrastructure as Code** (Reusable Terraform modules: RDS, ElastiCache, EKS)
- **Production monitoring** (CloudWatch alarms, Prometheus, Grafana)
- **Managed services** (RDS for PostgreSQL, ElastiCache for Redis - no K8s databases)



## 📄 License

MIT License - Use this for your portfolio!
