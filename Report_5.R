require(RODBC)
myconn <- odbcConnect("VidCast64")
sqlSelectStatement <- "select i.ItemName, r.TimesRestocked, o.TimesOrdered from Item i
left join (select ItemID, count(RestockID) as TimesRestocked from
ShelfRestock
where Date >= DATEADD(month, -3, getdate())
group by ItemID) r on i.ItemID = r.ItemID
left join (select ItemID, count(OrderID) as TimesOrdered from
InventoryOrder
where Date >= DATEADD(month, -3, getdate())
group by ItemID) o on i.ItemID = o.ItemID"
Report5 <- sqlQuery(myconn, sqlSelectStatement)
odbcCloseAll()
print(Report5)