require(RODBC)
myconn <- odbcConnect("VidCast64")
sqlSelectStatement <- "select top 10 i.ItemName, q.TotalPurchased from
Item i
join (select b.ItemID, sum(b.Quantity) as TotalPurchased from
Basket b
join Purchase p on p.PurchaseID = b.PurchaseID
where p.EndTime >= DATEADD(month, -1, getdate())
group by b.ItemID) q on i.ItemID = q.ItemID
order by q.TotalPurchased desc"
Report3 <- sqlQuery(myconn, sqlSelectStatement)
odbcCloseAll()
print(Report3)