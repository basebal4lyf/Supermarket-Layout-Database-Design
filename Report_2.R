require(RODBC)
myconn <- odbcConnect("VidCast64")
sqlSelectStatement <- "select s.Aisle, count(s.Aisle) as Occurences
from Shelf s
join Basket b on s.ItemID = b.ItemID
join ItemsPerPurchase i on b.PurchaseID = i.PurchaseID
where i.TotalQuantity >=10
group by s.Aisle
order by Occurences desc"
Report2 <- sqlQuery(myconn, sqlSelectStatement)
odbcCloseAll()
print(Report2)