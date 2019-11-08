require(RODBC)
myconn <- odbcConnect("VidCast64")
sqlSelectStatement <- "select p.CashierType, avg(datediff(second, p.StartTime, p.EndTime)) as AvgTime
from Purchase p
join Basket b on p.PurchaseID = b.PurchaseID
join ItemsPerPurchase i on i.PurchaseID = p.PurchaseID
where i.TotalQuantity >= 10
group by p.CashierType"
Report1 <- sqlQuery(myconn, sqlSelectStatement)
odbcCloseAll()
print(Report1)