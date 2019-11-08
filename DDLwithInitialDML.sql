/* IF TABLES EXIST, DROP THEM */
IF OBJECT_ID('dbo.ShelfRestock') IS NOT NULL
BEGIN
drop table dbo.ShelfRestock
END

IF OBJECT_ID('dbo.Shelf') IS NOT NULL
BEGIN
drop table dbo.Shelf
END

IF OBJECT_ID('dbo.InventoryOrder') IS NOT NULL
BEGIN
drop table dbo.InventoryOrder
END

IF OBJECT_ID('dbo.Inventory') IS NOT NULL
BEGIN
drop table dbo.Inventory
END

IF OBJECT_ID('dbo.Basket') IS NOT NULL
BEGIN
drop table dbo.Basket
END

IF OBJECT_ID('dbo.Item') IS NOT NULL
BEGIN
drop table dbo.Item
END

IF OBJECT_ID('dbo.Supplier') IS NOT NULL
BEGIN
drop table dbo.Supplier
END

IF OBJECT_ID('dbo.Purchase') IS NOT NULL
BEGIN
drop table dbo.Purchase
END

IF OBJECT_ID('dbo.Customer') IS NOT NULL
BEGIN
drop table dbo.Customer
END

go


/* CREATE TABLES */

-- Creating the Customer table
create table Customer (
	-- Columns
	CustomerID int identity,
	FirstName varchar(20),
	LastName varchar(20),
	EmailAddress varchar(50) not null,
	PhoneNumber varchar(20) not null,
	Gender varchar(1),
	DOB datetime,
	MaritalStatus varchar(10),
	SecondaryOf int,
	-- Constraints
	constraint PK_Customer primary key (CustomerID),
	constraint U1_Customer unique(EmailAddress),
	constraint U2_Customer unique(PhoneNumber)
)

-- Creating the Purchase table
create table Purchase (
	-- Columns
	PurchaseID int identity,
	CustomerID int not null,
	StartTime datetime not null default GetDate(),
	EndTime datetime,
	CashierType varchar(1) not null,
	-- Constraints
	constraint PK_Purchase primary key (PurchaseID),
	constraint FK1_Purchase foreign key (CustomerID) references Customer(CustomerID)
)

-- Creating the Supplier table
create table Supplier (
	-- Columns
	SupplierID int identity,
	Name varchar(50) not null,
	-- Constraints
	constraint PK_Supplier primary key (SupplierID),
	constraint U1_Supplier unique(Name)
)

-- Creating the Item table
create table Item (
	-- Columns
	ItemID int identity,
	ItemName varchar(20) not null,
	SupplierID int not null,
	-- Constraints
	constraint PK_Item primary key (ItemID),
	constraint U1_Item unique(ItemName),
	constraint FK1_Item foreign key (SupplierID) references Supplier(SupplierID)
)

-- Creating the Basket table
create table Basket (
	-- Columns
	BasketID int identity,
	PurchaseID int not null,
	ItemID int not null,
	Quantity int not null,
	-- Constraints
	constraint PK_Basket primary key (BasketID),
	constraint U1_Basket unique(PurchaseID, ItemID),
	constraint FK1_Basket foreign key (PurchaseID) references Purchase(PurchaseID),
	constraint FK2_Basket foreign key (ItemID) references Item(ItemID)
)

-- Creating the Inventory table
create table Inventory (
	-- Columns
	InventoryID int identity,
	Location varchar(10) not null,
	ItemID int not null,
	Quantity int not null,
	-- Constraints
	constraint PK_Inventory primary key (InventoryID),
	constraint U1_Inventory unique(Location, ItemID),
	constraint FK1_Inventory foreign key (ItemID) references Item(ItemID)
)

-- Creating the InventoryOrder table
create table InventoryOrder (
	-- Columns
	OrderID int identity,
	ItemID int not null,
	Quantity int not null,
	Date datetime not null default GetDate(),
	-- Constraints
	constraint PK_InventoryOrder primary key (OrderID),
	constraint FK1_InventoryOrder foreign key (ItemID) references Item(ItemID)
)

-- Creating the Shelf table
create table Shelf (
	-- Columns
	ShelfID int identity,
	Aisle varchar(2) not null,
	Height int not null,
	ItemID int,
	Quantity int,
	-- Constraints
	constraint PK_Shelf primary key (ShelfID),
	constraint FK1_Shelf foreign key (ItemID) references Item(ItemID),
	constraint U1_Shelft unique(Aisle, Height)
)

-- Creating the ShelfRestock table
create table ShelfRestock (
	-- Columns
	RestockID int identity,
	ShelfID int not null,
	ItemID int not null,
	Quantity int not null,
	Date datetime not null default GetDate(),
	-- Constraints
	constraint PK_ShelfRestock primary key (RestockID),
	constraint FK1_ShelfRestock foreign key (ShelfID) references Shelf(ShelfID),
	constraint FK2_ShelfRestock foreign key (ItemID) references Item(ItemID)
)

go


/* IF PROCEDURES EXIST, DROP THEM */
IF OBJECT_ID('dbo.OrderInventory') IS NOT NULL
BEGIN
drop procedure dbo.OrderInventory
END

IF OBJECT_ID('dbo.RestockShelf') IS NOT NULL
BEGIN
drop procedure dbo.RestockShelf
END

IF OBJECT_ID('dbo.InitializePurchase') IS NOT NULL
BEGIN
drop procedure dbo.InitializePurchase
END

IF OBJECT_ID('dbo.ScanItem') IS NOT NULL
BEGIN
drop procedure dbo.ScanItem
END

IF OBJECT_ID('dbo.FinalizePurchase') IS NOT NULL
BEGIN
drop procedure dbo.FinalizePurchase
END

go

/* CREATE PROCEDURES */
-- Creating procedure to record Inventory Order
create procedure OrderInventory(@itemName varchar(20), @quantity int, @location varchar(10)) as
begin
	-- get ItemID for Foreign Key from Item table
	declare @ItemID int
	select @ItemID = ItemID from Item where ItemName = @itemName;

	-- Start a transaction because Order and Inventory need to be updated simultaneously
	begin tran;
		insert into InventoryOrder (ItemID, Quantity) values (@ItemID, @quantity);
		insert into Inventory (Location, ItemID, Quantity) values (@location, @ItemID, @quantity);
	commit tran
end
go

-- Creating procedure to record Shelf Restock
create procedure RestockShelf(@itemName varchar(20), @quantity int, @aisle varchar(2), @height int) as
begin
	-- get ItemID from Item table and ShelfID from Shelf table for Foreign Keys
	declare @ItemID int
	declare @ShelfID int
	select @ItemID = ItemID from Item where ItemName = @itemName;
	select @ShelfID = ShelfID from Shelf where Aisle = @aisle and Height = @height;
	
	-- The store wants to use up smallest inventories, so we need to get the associated InventoryID to update later
	declare @InventoryID int
	select top 1 @InventoryID = InventoryID from Inventory where ItemID = @ItemID order by Quantity asc

	-- Start a transaction because Restock, Shelf, and Inventory all need to be updated simultaneously
	begin tran;
		insert into ShelfRestock (ShelfID, ItemID, Quantity) values (@ShelfID, @ItemID, @quantity);
		-- If the item being restocked was already on that shelf, only update the quantity
		-- If there was a different item on that shelf, update the itemID and the quantity
		if exists (select * from Shelf where ShelfID = @ShelfID and ItemID = @ItemID)
			begin
			update Shelf set Quantity = Quantity + @quantity where ShelfID = @ShelfID and ItemID = @ItemID;
			end
		else
			begin
			update Shelf set ItemID = @ItemID, Quantity = @quantity where ShelfID = @ShelfID;
			end
		-- We need to update the Inventory table as items are moved from storage to the floor
		update Inventory set Quantity = Quantity - @quantity where InventoryID = @InventoryID;
		-- If an inventory reaches 0, additional restock quantity should be entered separately
	commit tran
end
go

-- Create procedure to initialize a purchase at an automate register
-- Purchases begin when a customer enters their phone number at the register to verify membership
-- In practice, cash register would automatically pass @cashierType, but here we need to manually input it
create procedure InitializePurchase (@phoneNumber varchar(20), @cashierType varchar(1))
as
begin
	-- get CustomerID from Customer table for Foreign Key
	declare @CustomerID int
	select @CustomerID = CustomerID from Customer where PhoneNumber = @phoneNumber;

	insert into Purchase (CustomerID, CashierType) values (@CustomerID, @cashierType);
	
	-- Return newly created PurchaseID for Creating Basket
	return @@identity
end
go

-- Creating procedure to create Basket as Items are scanned
-- @PurchaseID should always be @@identity, which was returned by InitializePurchase
create procedure ScanItem(@itemName varchar(20), @PurchaseID int) as
begin
	-- get ItemID from Item table for Foreign Key
	declare @ItemID int
	select @ItemID = ItemID from Item where ItemName = @itemName;

	-- If the item was already in the basket, only update the quantity
	-- If the item is being added for the first time, insert the itemID and purchaseID
	if exists (select * from Basket where PurchaseID = @PurchaseID and ItemID = @ItemID)
		begin
		update Basket set Quantity = Quantity + 1 where PurchaseID = @PurchaseID and ItemID = @ItemID;
		end
	else
		begin
		insert into Basket (PurchaseID, ItemID, Quantity) values (@PurchaseID, @ItemID, 1);
		end
end
go

-- Creating procedure to finalize Purchase
-- @PurchaseID should always be @@identity, which was returned by InitializePurchase
create procedure FinalizePurchase(@PurchaseID int) as
begin
	update Purchase set EndTime = GetDate() where PurchaseID = @PurchaseID
end
go

-- Load Suppliers into Supplier table
insert into Supplier (Name) values ('Turducken Co');
insert into Supplier (Name) values ('Stuffs R Us');
insert into Supplier (Name) values ('All That Jazz Inc.');
insert into Supplier (Name) values ('Cramazon.com');
insert into Supplier (Name) values ('BunchOStuff Corp');
go

-- Load Items into Item table
insert into Item (ItemName, SupplierID) values ('Apple', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Orange', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Smart Watch', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Laptop', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Camping Tent', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Socks', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Shirt', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Granola Bar', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Toothpaste', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Spoon', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Micromave', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Notebook', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Baseball', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Scissors', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Fan', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Lamp', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Light Bulb', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Jacket', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Pizza', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Cupcake', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Ice Cream', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Carrot', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Broccoli', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Suit Case', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Umbrella', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Pool Noodle', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Camera', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Book', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Lawn Chair', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Video Game', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Tape', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Stapler', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Armband', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Pull Up Bar', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Bench', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Treadmill', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Picture', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Frame', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Doorknob', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Screw', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Hammer', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Wall Hook', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Trading Card Pack', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Multivitamin', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Athletic Tape', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
go

-- Load Customers into Customer table
insert into Customer (EmailAddress, PhoneNumber) values ('hoogla@boogla.net','234-567-8901');
insert into Customer (EmailAddress, PhoneNumber) values ('jane@doe.com','234-567-8902');
insert into Customer (EmailAddress, PhoneNumber) values ('who@dat.org','234-567-8903');
insert into Customer (EmailAddress, PhoneNumber) values ('whats@up.com','234-567-8904');
insert into Customer (EmailAddress, PhoneNumber) values ('ka@pow.net','234-567-8905');
insert into Customer (EmailAddress, PhoneNumber) values ('splish@splash.org','234-567-8906');
insert into Customer (EmailAddress, PhoneNumber) values ('some@dude.com','234-567-8907');
insert into Customer (EmailAddress, PhoneNumber) values ('some@dudette.com','234-567-8908');
go

-- Load empty Shelves into Shelf table
insert into Shelf (Aisle, Height) values('A0',1);
insert into Shelf (Aisle, Height) values('A1',1);
insert into Shelf (Aisle, Height) values('A2',1);
insert into Shelf (Aisle, Height) values('A3',1);
insert into Shelf (Aisle, Height) values('A4',1);
insert into Shelf (Aisle, Height) values('B0',1);
insert into Shelf (Aisle, Height) values('B1',1);
insert into Shelf (Aisle, Height) values('B2',1);
insert into Shelf (Aisle, Height) values('B3',1);
insert into Shelf (Aisle, Height) values('B4',1);
insert into Shelf (Aisle, Height) values('C0',1);
insert into Shelf (Aisle, Height) values('C1',1);
insert into Shelf (Aisle, Height) values('C2',1);
insert into Shelf (Aisle, Height) values('C3',1);
insert into Shelf (Aisle, Height) values('C4',1);
insert into Shelf (Aisle, Height) values('A0',2);
insert into Shelf (Aisle, Height) values('A1',2);
insert into Shelf (Aisle, Height) values('A2',2);
insert into Shelf (Aisle, Height) values('A3',2);
insert into Shelf (Aisle, Height) values('A4',2);
insert into Shelf (Aisle, Height) values('B0',2);
insert into Shelf (Aisle, Height) values('B1',2);
insert into Shelf (Aisle, Height) values('B2',2);
insert into Shelf (Aisle, Height) values('B3',2);
insert into Shelf (Aisle, Height) values('B4',2);
insert into Shelf (Aisle, Height) values('C0',2);
insert into Shelf (Aisle, Height) values('C1',2);
insert into Shelf (Aisle, Height) values('C2',2);
insert into Shelf (Aisle, Height) values('C3',2);
insert into Shelf (Aisle, Height) values('C4',2);
insert into Shelf (Aisle, Height) values('A0',3);
insert into Shelf (Aisle, Height) values('A1',3);
insert into Shelf (Aisle, Height) values('A2',3);
insert into Shelf (Aisle, Height) values('A3',3);
insert into Shelf (Aisle, Height) values('A4',3);
insert into Shelf (Aisle, Height) values('B0',3);
insert into Shelf (Aisle, Height) values('B1',3);
insert into Shelf (Aisle, Height) values('B2',3);
insert into Shelf (Aisle, Height) values('B3',3);
insert into Shelf (Aisle, Height) values('B4',3);
insert into Shelf (Aisle, Height) values('C0',3);
insert into Shelf (Aisle, Height) values('C1',3);
insert into Shelf (Aisle, Height) values('C2',3);
insert into Shelf (Aisle, Height) values('C3',3);
insert into Shelf (Aisle, Height) values('C4',3);
go

-- Stock inventory for the first time
exec OrderInventory 'Micromave',11,'shelf86';
exec OrderInventory 'Cupcake',109,'shelf50';
exec OrderInventory 'Notebook',35,'shelf132';
exec OrderInventory 'Ice Cream',81,'shelf141';
exec OrderInventory 'Video Game',47,'place30';
exec OrderInventory 'Suit Case',21,'pallet129';
exec OrderInventory 'Smart Watch',37,'pallet108';
exec OrderInventory 'Hammer',64,'shelf71';
exec OrderInventory 'Multivitamin',65,'shelf29';
exec OrderInventory 'Socks',16,'place6';
exec OrderInventory 'Ice Cream',17,'shelf6';
exec OrderInventory 'Spoon',95,'place100';
exec OrderInventory 'Frame',97,'pallet98';
exec OrderInventory 'Fan',76,'place60';
exec OrderInventory 'Baseball',108,'place103';
exec OrderInventory 'Picture',55,'place37';
exec OrderInventory 'Light Bulb',16,'pallet77';
exec OrderInventory 'Camera',100,'pallet87';
exec OrderInventory 'Stapler',37,'pallet137';
exec OrderInventory 'Shirt',40,'place52';
exec OrderInventory 'Cupcake',51,'shelf140';
exec OrderInventory 'Multivitamin',23,'pallet104';
exec OrderInventory 'Granola Bar',103,'pallet113';
exec OrderInventory 'Athletic Tape',77,'place135';
exec OrderInventory 'Picture',102,'shelf112';
exec OrderInventory 'Book',48,'shelf13';
exec OrderInventory 'Video Game',83,'pallet90';
exec OrderInventory 'Athletic Tape',48,'pallet105';
exec OrderInventory 'Carrot',75,'shelf52';
exec OrderInventory 'Armband',33,'place78';
exec OrderInventory 'Spoon',45,'place145';
exec OrderInventory 'Fan',103,'place105';
exec OrderInventory 'Toothpaste',98,'place144';
exec OrderInventory 'Suit Case',91,'shelf99';
exec OrderInventory 'Pool Noodle',11,'place26';
exec OrderInventory 'Pool Noodle',54,'place71';
exec OrderInventory 'Picture',85,'place127';
exec OrderInventory 'Tape',64,'shelf16';
exec OrderInventory 'Bench',81,'pallet5';
exec OrderInventory 'Screw',106,'place40';
exec OrderInventory 'Bench',92,'shelf65';
exec OrderInventory 'Lawn Chair',99,'pallet44';
exec OrderInventory 'Granola Bar',84,'shelf83';
exec OrderInventory 'Orange',66,'pallet17';
exec OrderInventory 'Book',14,'shelf58';
exec OrderInventory 'Screw',44,'place130';
exec OrderInventory 'Smart Watch',80,'shelf78';
exec OrderInventory 'Micromave',41,'place56';
exec OrderInventory 'Bench',37,'place125';
exec OrderInventory 'Armband',31,'place33';
exec OrderInventory 'Lamp',26,'pallet76';
exec OrderInventory 'Lamp',73,'shelf136';
exec OrderInventory 'Spoon',67,'place10';
exec OrderInventory 'Lawn Chair',79,'place119';
exec OrderInventory 'Spoon',82,'shelf85';
exec OrderInventory 'Broccoli',45,'place68';
exec OrderInventory 'Toothpaste',99,'shelf129';
exec OrderInventory 'Shirt',77,'pallet112';
exec OrderInventory 'Lawn Chair',42,'shelf59';
exec OrderInventory 'Scissors',105,'pallet74';
exec OrderInventory 'Pool Noodle',33,'shelf56';
exec OrderInventory 'Spoon',42,'shelf40';
exec OrderInventory 'Baseball',27,'place148';
exec OrderInventory 'Doorknob',31,'shelf114';
exec OrderInventory 'Umbrella',20,'shelf10';
exec OrderInventory 'Broccoli',87,'place23';
exec OrderInventory 'Stapler',56,'place32';
exec OrderInventory 'Smart Watch',31,'place48';
exec OrderInventory 'Spoon',66,'shelf130';
exec OrderInventory 'Umbrella',105,'place115';
exec OrderInventory 'Lawn Chair',65,'shelf149';
exec OrderInventory 'Wall Hook',31,'shelf27';
exec OrderInventory 'Trading Card Pack',47,'pallet148';
exec OrderInventory 'Socks',34,'pallet66';
exec OrderInventory 'Pizza',12,'place109';
exec OrderInventory 'Book',101,'pallet133';
exec OrderInventory 'Frame',85,'place128';
exec OrderInventory 'Baseball',48,'place13';
exec OrderInventory 'Umbrella',36,'pallet130';
exec OrderInventory 'Scissors',102,'shelf134';
exec OrderInventory 'Pull Up Bar',41,'pallet49';
exec OrderInventory 'Doorknob',19,'pallet99';
exec OrderInventory 'Apple',40,'pallet106';
exec OrderInventory 'Bench',56,'pallet50';
exec OrderInventory 'Video Game',45,'pallet45';
exec OrderInventory 'Bench',23,'pallet95';
exec OrderInventory 'Doorknob',105,'pallet144';
exec OrderInventory 'Lawn Chair',31,'place29';
exec OrderInventory 'Treadmill',68,'pallet141';
exec OrderInventory 'Video Game',77,'place75';
exec OrderInventory 'Picture',21,'pallet97';
exec OrderInventory 'Smart Watch',94,'pallet18';
exec OrderInventory 'Apple',92,'place1';
exec OrderInventory 'Scissors',33,'pallet119';
exec OrderInventory 'Video Game',56,'place120';
exec OrderInventory 'Light Bulb',73,'place107';
exec OrderInventory 'Book',88,'pallet43';
exec OrderInventory 'Orange',33,'shelf77';
exec OrderInventory 'Treadmill',88,'shelf111';
exec OrderInventory 'Baseball',107,'shelf133';
exec OrderInventory 'Jacket',86,'place108';
exec OrderInventory 'Shirt',44,'shelf82';
exec OrderInventory 'Pizza',24,'shelf49';
exec OrderInventory 'Lamp',55,'shelf91';
exec OrderInventory 'Shirt',53,'shelf127';
exec OrderInventory 'Pull Up Bar',21,'pallet4';
exec OrderInventory 'Trading Card Pack',40,'pallet13';
exec OrderInventory 'Toothpaste',77,'place54';
exec OrderInventory 'Pool Noodle',38,'place116';
exec OrderInventory 'Lamp',11,'pallet121';
exec OrderInventory 'Notebook',14,'pallet27';
exec OrderInventory 'Armband',93,'shelf108';
exec OrderInventory 'Wall Hook',23,'place87';
exec OrderInventory 'Tape',60,'place76';
exec OrderInventory 'Apple',81,'place46';
exec OrderInventory 'Hammer',92,'pallet56';
exec OrderInventory 'Picture',60,'pallet142';
exec OrderInventory 'Hammer',73,'pallet101';
exec OrderInventory 'Treadmill',31,'pallet51';
exec OrderInventory 'Pool Noodle',23,'shelf11';
exec OrderInventory 'Cupcake',10,'shelf95';
exec OrderInventory 'Notebook',102,'place147';
exec OrderInventory 'Orange',34,'place137';
exec OrderInventory 'Stapler',23,'place77';
exec OrderInventory 'Wall Hook',13,'pallet102';
exec OrderInventory 'Micromave',30,'place101';
exec OrderInventory 'Camping Tent',88,'place5';
exec OrderInventory 'Frame',31,'shelf113';
exec OrderInventory 'Camera',104,'shelf147';
exec OrderInventory 'Stapler',23,'place122';
exec OrderInventory 'Scissors',49,'shelf44';
exec OrderInventory 'Athletic Tape',80,'pallet150';
exec OrderInventory 'Notebook',51,'shelf87';
exec OrderInventory 'Notebook',22,'place57';
exec OrderInventory 'Lamp',10,'pallet31';
exec OrderInventory 'Treadmill',95,'place81';
exec OrderInventory 'Screw',106,'shelf115';
exec OrderInventory 'Socks',82,'place141';
exec OrderInventory 'Video Game',99,'shelf150';
exec OrderInventory 'Lawn Chair',46,'shelf14';
exec OrderInventory 'Frame',23,'place38';
exec OrderInventory 'Athletic Tape',85,'shelf75';
exec OrderInventory 'Laptop',50,'shelf124';
exec OrderInventory 'Broccoli',59,'shelf8';
exec OrderInventory 'Socks',71,'shelf36';
exec OrderInventory 'Socks',83,'shelf126';
exec OrderInventory 'Apple',68,'pallet16';
exec OrderInventory 'Bench',97,'shelf110';
exec OrderInventory 'Book',36,'place118';
exec OrderInventory 'Trading Card Pack',44,'place133';
exec OrderInventory 'Socks',54,'place51';
exec OrderInventory 'Granola Bar',28,'shelf38';
exec OrderInventory 'Wall Hook',70,'place132';
exec OrderInventory 'Athletic Tape',53,'pallet15';
exec OrderInventory 'Laptop',35,'shelf34';
exec OrderInventory 'Suit Case',80,'shelf54';
exec OrderInventory 'Stapler',73,'pallet92';
exec OrderInventory 'Apple',17,'place91';
exec OrderInventory 'Granola Bar',83,'shelf128';
exec OrderInventory 'Orange',52,'place2';
exec OrderInventory 'Baseball',50,'pallet118';
exec OrderInventory 'Stapler',105,'pallet2';
exec OrderInventory 'Cupcake',24,'place110';
exec OrderInventory 'Tape',60,'shelf61';
exec OrderInventory 'Lawn Chair',48,'place74';
exec OrderInventory 'Spoon',22,'pallet70';
exec OrderInventory 'Screw',76,'shelf25';
exec OrderInventory 'Micromave',66,'place146';
exec OrderInventory 'Broccoli',91,'shelf53';
exec OrderInventory 'Armband',88,'place123';
exec OrderInventory 'Doorknob',59,'shelf69';
exec OrderInventory 'Cupcake',94,'place20';
exec OrderInventory 'Screw',52,'pallet145';
exec OrderInventory 'Ice Cream',18,'shelf96';
exec OrderInventory 'Scissors',10,'place14';
exec OrderInventory 'Treadmill',105,'place126';
exec OrderInventory 'Trading Card Pack',106,'shelf73';
exec OrderInventory 'Camping Tent',62,'place50';
exec OrderInventory 'Pull Up Bar',35,'shelf109';
exec OrderInventory 'Screw',97,'pallet10';
exec OrderInventory 'Treadmill',24,'shelf21';
exec OrderInventory 'Camera',86,'shelf12';
exec OrderInventory 'Ice Cream',48,'place21';
exec OrderInventory 'Doorknob',63,'place39';
exec OrderInventory 'Apple',28,'place136';
exec OrderInventory 'Stapler',41,'shelf17';
exec OrderInventory 'Scissors',28,'place59';
exec OrderInventory 'Camera',55,'place72';
exec OrderInventory 'Micromave',39,'pallet71';
exec OrderInventory 'Broccoli',43,'shelf98';
exec OrderInventory 'Video Game',13,'shelf105';
exec OrderInventory 'Stapler',75,'pallet47';
exec OrderInventory 'Apple',49,'pallet61';
exec OrderInventory 'Ice Cream',68,'place66';
exec OrderInventory 'Ice Cream',12,'shelf51';
exec OrderInventory 'Frame',17,'pallet53';
exec OrderInventory 'Jacket',89,'pallet78';
exec OrderInventory 'Smart Watch',31,'pallet63';
exec OrderInventory 'Camera',68,'pallet42';
exec OrderInventory 'Lamp',35,'place16';
exec OrderInventory 'Smart Watch',90,'place3';
exec OrderInventory 'Camping Tent',40,'pallet65';
exec OrderInventory 'Trading Card Pack',54,'pallet58';
exec OrderInventory 'Laptop',32,'place94';
exec OrderInventory 'Camping Tent',49,'pallet20';
exec OrderInventory 'Light Bulb',70,'shelf137';
exec OrderInventory 'Carrot',72,'place22';
exec OrderInventory 'Athletic Tape',70,'place45';
exec OrderInventory 'Frame',83,'shelf68';
exec OrderInventory 'Camping Tent',14,'shelf35';
exec OrderInventory 'Fan',76,'shelf45';
exec OrderInventory 'Multivitamin',60,'pallet14';
exec OrderInventory 'Broccoli',23,'pallet83';
exec OrderInventory 'Carrot',21,'pallet82';
exec OrderInventory 'Jacket',52,'pallet33';
exec OrderInventory 'Athletic Tape',90,'shelf30';
exec OrderInventory 'Multivitamin',51,'pallet59';
exec OrderInventory 'Treadmill',75,'pallet96';
exec OrderInventory 'Tape',29,'shelf106';
exec OrderInventory 'Laptop',22,'pallet109';
exec OrderInventory 'Pool Noodle',69,'pallet86';
exec OrderInventory 'Trading Card Pack',13,'place43';
exec OrderInventory 'Carrot',95,'pallet37';
exec OrderInventory 'Video Game',108,'shelf15';
exec OrderInventory 'Shirt',68,'pallet22';
exec OrderInventory 'Hammer',91,'shelf116';
exec OrderInventory 'Light Bulb',36,'pallet32';
exec OrderInventory 'Treadmill',101,'place36';
exec OrderInventory 'Tape',84,'pallet136';
exec OrderInventory 'Umbrella',32,'shelf100';
exec OrderInventory 'Trading Card Pack',37,'place88';
exec OrderInventory 'Fan',88,'place15';
exec OrderInventory 'Lawn Chair',39,'shelf104';
exec OrderInventory 'Laptop',57,'place139';
exec OrderInventory 'Socks',56,'shelf81';
exec OrderInventory 'Shirt',60,'place142';
exec OrderInventory 'Ice Cream',91,'pallet126';
exec OrderInventory 'Apple',62,'shelf121';
exec OrderInventory 'Notebook',41,'place102';
exec OrderInventory 'Laptop',96,'place4';
exec OrderInventory 'Notebook',42,'shelf42';
exec OrderInventory 'Camping Tent',81,'place140';
exec OrderInventory 'Micromave',49,'shelf41';
exec OrderInventory 'Athletic Tape',76,'pallet60';
exec OrderInventory 'Suit Case',28,'place24';
exec OrderInventory 'Picture',21,'place82';
exec OrderInventory 'Camera',92,'shelf57';
exec OrderInventory 'Carrot',49,'shelf7';
exec OrderInventory 'Fan',36,'pallet30';
exec OrderInventory 'Jacket',48,'shelf93';
exec OrderInventory 'Suit Case',109,'pallet84';
exec OrderInventory 'Laptop',51,'place49';
exec OrderInventory 'Toothpaste',88,'shelf39';
exec OrderInventory 'Jacket',89,'place18';
exec OrderInventory 'Pull Up Bar',96,'place34';
exec OrderInventory 'Athletic Tape',57,'place90';
exec OrderInventory 'Pull Up Bar',32,'shelf64';
exec OrderInventory 'Smart Watch',88,'place138';
exec OrderInventory 'Pool Noodle',41,'shelf146';
exec OrderInventory 'Tape',14,'pallet46';
exec OrderInventory 'Camping Tent',54,'shelf125';
exec OrderInventory 'Toothpaste',50,'pallet24';
exec OrderInventory 'Armband',21,'pallet93';
exec OrderInventory 'Camera',28,'place27';
exec OrderInventory 'Socks',93,'pallet111';
exec OrderInventory 'Shirt',15,'shelf37';
exec OrderInventory 'Orange',17,'pallet107';
exec OrderInventory 'Jacket',45,'shelf138';
exec OrderInventory 'Athletic Tape',103,'shelf120';
exec OrderInventory 'Light Bulb',59,'shelf92';
exec OrderInventory 'Book',40,'shelf103';
exec OrderInventory 'Lamp',91,'shelf1';
exec OrderInventory 'Wall Hook',18,'shelf117';
exec OrderInventory 'Doorknob',86,'pallet54';
exec OrderInventory 'Apple',86,'shelf76';
exec OrderInventory 'Frame',95,'shelf23';
exec OrderInventory 'Socks',21,'pallet21';
exec OrderInventory 'Pool Noodle',79,'shelf101';
exec OrderInventory 'Doorknob',47,'place84';
exec OrderInventory 'Wall Hook',30,'pallet57';
exec OrderInventory 'Ice Cream',21,'pallet81';
exec OrderInventory 'Picture',28,'shelf67';
exec OrderInventory 'Umbrella',48,'shelf55';
exec OrderInventory 'Suit Case',21,'place69';
exec OrderInventory 'Camping Tent',108,'shelf80';
exec OrderInventory 'Book',52,'pallet88';
exec OrderInventory 'Shirt',99,'place7';
exec OrderInventory 'Pull Up Bar',85,'pallet94';
exec OrderInventory 'Bench',82,'place80';
exec OrderInventory 'Broccoli',64,'pallet38';
exec OrderInventory 'Orange',13,'place47';
exec OrderInventory 'Fan',39,'shelf135';
exec OrderInventory 'Pizza',70,'pallet79';
exec OrderInventory 'Screw',35,'pallet100';
exec OrderInventory 'Shirt',83,'pallet67';
exec OrderInventory 'Baseball',101,'pallet73';
exec OrderInventory 'Book',80,'place28';
exec OrderInventory 'Light Bulb',43,'place62';
exec OrderInventory 'Carrot',60,'place112';
exec OrderInventory 'Ice Cream',51,'pallet36';
exec OrderInventory 'Wall Hook',86,'pallet12';
exec OrderInventory 'Umbrella',58,'pallet40';
exec OrderInventory 'Toothpaste',88,'pallet114';
exec OrderInventory 'Baseball',43,'pallet28';
exec OrderInventory 'Granola Bar',97,'place98';
exec OrderInventory 'Trading Card Pack',101,'pallet103';
exec OrderInventory 'Ice Cream',78,'place111';
exec OrderInventory 'Hammer',103,'place86';
exec OrderInventory 'Pizza',34,'shelf139';
exec OrderInventory 'Light Bulb',99,'shelf2';
exec OrderInventory 'Micromave',86,'pallet26';
exec OrderInventory 'Cupcake',46,'pallet35';
exec OrderInventory 'Tape',11,'place121';
exec OrderInventory 'Armband',84,'pallet138';
exec OrderInventory 'Cupcake',78,'pallet125';
exec OrderInventory 'Shirt',77,'place97';
exec OrderInventory 'Jacket',81,'shelf48';
exec OrderInventory 'Toothpaste',71,'place9';
exec OrderInventory 'Camera',100,'shelf102';
exec OrderInventory 'Broccoli',56,'place113';
exec OrderInventory 'Multivitamin',65,'shelf74';
exec OrderInventory 'Wall Hook',32,'place42';
exec OrderInventory 'Scissors',69,'shelf89';
exec OrderInventory 'Bench',13,'pallet140';
exec OrderInventory 'Smart Watch',90,'place93';
exec OrderInventory 'Umbrella',44,'place70';
exec OrderInventory 'Suit Case',21,'shelf9';
exec OrderInventory 'Granola Bar',37,'place53';
exec OrderInventory 'Multivitamin',29,'place44';
exec OrderInventory 'Scissors',28,'place104';
exec OrderInventory 'Stapler',28,'shelf107';
exec OrderInventory 'Umbrella',69,'shelf145';
exec OrderInventory 'Pool Noodle',97,'pallet41';
exec OrderInventory 'Screw',69,'shelf70';
exec OrderInventory 'Granola Bar',45,'place143';
exec OrderInventory 'Video Game',33,'shelf60';
exec OrderInventory 'Umbrella',30,'pallet85';
exec OrderInventory 'Trading Card Pack',67,'shelf118';
exec OrderInventory 'Camera',67,'pallet132';
exec OrderInventory 'Carrot',68,'place67';
exec OrderInventory 'Pull Up Bar',40,'place124';
exec OrderInventory 'Lamp',69,'place106';
exec OrderInventory 'Orange',107,'place92';
exec OrderInventory 'Camping Tent',31,'place95';
exec OrderInventory 'Treadmill',20,'pallet6';
exec OrderInventory 'Scissors',39,'place149';
exec OrderInventory 'Cupcake',94,'pallet80';
exec OrderInventory 'Broccoli',89,'pallet128';
exec OrderInventory 'Hammer',78,'pallet146';
exec OrderInventory 'Light Bulb',86,'place17';
exec OrderInventory 'Pizza',15,'shelf94';
exec OrderInventory 'Hammer',40,'place41';
exec OrderInventory 'Frame',61,'pallet8';
exec OrderInventory 'Camping Tent',28,'pallet110';
exec OrderInventory 'Laptop',82,'shelf79';
exec OrderInventory 'Baseball',25,'shelf43';
exec OrderInventory 'Lamp',33,'place61';
exec OrderInventory 'Light Bulb',12,'shelf47';
exec OrderInventory 'Spoon',81,'place55';
exec OrderInventory 'Carrot',94,'pallet127';
exec OrderInventory 'Armband',29,'shelf63';
exec OrderInventory 'Orange',10,'shelf122';
exec OrderInventory 'Notebook',24,'place12';
exec OrderInventory 'Frame',87,'place83';
exec OrderInventory 'Granola Bar',90,'pallet68';
exec OrderInventory 'Lawn Chair',61,'pallet89';
exec OrderInventory 'Frame',79,'pallet143';
exec OrderInventory 'Doorknob',62,'shelf24';
exec OrderInventory 'Armband',96,'pallet3';
exec OrderInventory 'Tape',101,'pallet91';
exec OrderInventory 'Carrot',49,'shelf142';
exec OrderInventory 'Hammer',84,'shelf26';
exec OrderInventory 'Treadmill',30,'shelf66';
exec OrderInventory 'Light Bulb',22,'pallet122';
exec OrderInventory 'Multivitamin',45,'shelf119';
exec OrderInventory 'Broccoli',93,'shelf143';
exec OrderInventory 'Pizza',56,'pallet124';
exec OrderInventory 'Orange',73,'shelf32';
exec OrderInventory 'Jacket',22,'pallet123';
exec OrderInventory 'Picture',76,'pallet52';
exec OrderInventory 'Multivitamin',75,'pallet149';
exec OrderInventory 'Bench',79,'shelf20';
exec OrderInventory 'Socks',100,'place96';
exec OrderInventory 'Lawn Chair',94,'pallet134';
exec OrderInventory 'Pull Up Bar',105,'pallet139';
exec OrderInventory 'Baseball',30,'place58';
exec OrderInventory 'Wall Hook',17,'shelf72';
exec OrderInventory 'Umbrella',46,'place25';
exec OrderInventory 'Pizza',92,'pallet34';
exec OrderInventory 'Doorknob',39,'place129';
exec OrderInventory 'Micromave',93,'place11';
exec OrderInventory 'Smart Watch',49,'shelf123';
exec OrderInventory 'Granola Bar',34,'place8';
exec OrderInventory 'Orange',25,'pallet62';
exec OrderInventory 'Hammer',47,'place131';
exec OrderInventory 'Smart Watch',16,'shelf33';
exec OrderInventory 'Pizza',37,'shelf4';
exec OrderInventory 'Laptop',12,'pallet19';
exec OrderInventory 'Pull Up Bar',45,'shelf19';
exec OrderInventory 'Video Game',66,'pallet135';
exec OrderInventory 'Suit Case',81,'pallet39';
exec OrderInventory 'Multivitamin',75,'place89';
exec OrderInventory 'Fan',108,'pallet120';
exec OrderInventory 'Camera',39,'place117';
exec OrderInventory 'Bench',50,'place35';
exec OrderInventory 'Cupcake',74,'shelf5';
exec OrderInventory 'Wall Hook',78,'pallet147';
exec OrderInventory 'Picture',45,'pallet7';
exec OrderInventory 'Stapler',57,'shelf62';
exec OrderInventory 'Screw',91,'pallet55';
exec OrderInventory 'Carrot',48,'shelf97';
exec OrderInventory 'Jacket',13,'place63';
exec OrderInventory 'Pull Up Bar',46,'place79';
exec OrderInventory 'Granola Bar',91,'pallet23';
exec OrderInventory 'Picture',60,'shelf22';
exec OrderInventory 'Armband',103,'shelf18';
exec OrderInventory 'Laptop',69,'pallet64';
exec OrderInventory 'Pizza',46,'place19';
exec OrderInventory 'Pizza',67,'place64';
exec OrderInventory 'Fan',106,'place150';
exec OrderInventory 'Notebook',34,'pallet72';
exec OrderInventory 'Pool Noodle',12,'pallet131';
exec OrderInventory 'Lamp',17,'shelf46';
exec OrderInventory 'Book',104,'place73';
exec OrderInventory 'Micromave',62,'shelf131';
exec OrderInventory 'Spoon',101,'pallet115';
exec OrderInventory 'Toothpaste',77,'place99';
exec OrderInventory 'Tape',40,'pallet1';
exec OrderInventory 'Toothpaste',33,'shelf84';
exec OrderInventory 'Baseball',90,'shelf88';
exec OrderInventory 'Apple',89,'shelf31';
exec OrderInventory 'Suit Case',67,'shelf144';
exec OrderInventory 'Trading Card Pack',52,'shelf28';
exec OrderInventory 'Armband',17,'pallet48';
exec OrderInventory 'Spoon',59,'pallet25';
exec OrderInventory 'Notebook',26,'pallet117';
exec OrderInventory 'Multivitamin',56,'place134';
exec OrderInventory 'Scissors',24,'pallet29';
exec OrderInventory 'Fan',25,'pallet75';
exec OrderInventory 'Cupcake',15,'place65';
exec OrderInventory 'Screw',80,'place85';
exec OrderInventory 'Toothpaste',101,'pallet69';
exec OrderInventory 'Doorknob',44,'pallet9';
exec OrderInventory 'Micromave',71,'pallet116';
exec OrderInventory 'Suit Case',24,'place114';
exec OrderInventory 'Hammer',84,'pallet11';
exec OrderInventory 'Fan',53,'shelf90';
exec OrderInventory 'Tape',47,'place31';
exec OrderInventory 'Jacket',84,'shelf3';
exec OrderInventory 'Book',39,'shelf148';
go

-- Stock shelves for the first time
exec RestockShelf 'Athletic Tape',19,'C4',3;
exec RestockShelf 'Hammer',6,'C0',3;
exec RestockShelf 'Trading Card Pack',18,'C2',3;
exec RestockShelf 'Pizza',15,'A3',2;
exec RestockShelf 'Spoon',6,'B4',1;
exec RestockShelf 'Granola Bar',14,'B2',1;
exec RestockShelf 'Video Game',18,'C4',2;
exec RestockShelf 'Jacket',21,'A2',2;
exec RestockShelf 'Wall Hook',12,'C1',3;
exec RestockShelf 'Baseball',6,'C2',1;
exec RestockShelf 'Fan',8,'C4',1;
exec RestockShelf 'Ice Cream',11,'B0',2;
exec RestockShelf 'Camera',5,'C1',2;
exec RestockShelf 'Armband',10,'A2',3;
exec RestockShelf 'Micromave',12,'C0',1;
exec RestockShelf 'Ice Cream',9,'B0',2;
exec RestockShelf 'Light Bulb',10,'A1',2;
exec RestockShelf 'Camera',24,'C1',2;
exec RestockShelf 'Multivitamin',16,'C3',3;
exec RestockShelf 'Cupcake',13,'A4',2;
exec RestockShelf 'Fan',7,'C4',1;
exec RestockShelf 'Orange',7,'A1',1;
exec RestockShelf 'Hammer',22,'C0',3;
exec RestockShelf 'Bench',24,'A4',3;
exec RestockShelf 'Baseball',16,'C2',1;
exec RestockShelf 'Wall Hook',22,'C1',3;
exec RestockShelf 'Toothpaste',10,'B3',1;
exec RestockShelf 'Athletic Tape',14,'C4',3;
exec RestockShelf 'Micromave',9,'C0',1;
exec RestockShelf 'Spoon',18,'B4',1;
exec RestockShelf 'Camera',9,'C1',2;
exec RestockShelf 'Pizza',20,'A3',2;
exec RestockShelf 'Jacket',17,'A2',2;
exec RestockShelf 'Screw',16,'B4',3;
exec RestockShelf 'Socks',18,'B0',1;
exec RestockShelf 'Book',9,'C2',2;
exec RestockShelf 'Frame',20,'B2',3;
exec RestockShelf 'Frame',12,'B2',3;
exec RestockShelf 'Camera',21,'C1',2;
exec RestockShelf 'Trading Card Pack',20,'C2',3;
exec RestockShelf 'Frame',19,'B2',3;
exec RestockShelf 'Apple',21,'A0',1;
exec RestockShelf 'Book',23,'C2',2;
exec RestockShelf 'Stapler',12,'A1',3;
exec RestockShelf 'Spoon',8,'B4',1;
exec RestockShelf 'Multivitamin',7,'C3',3;
exec RestockShelf 'Pull Up Bar',22,'A3',3;
exec RestockShelf 'Jacket',17,'A2',2;
exec RestockShelf 'Treadmill',9,'B0',3;
exec RestockShelf 'Screw',19,'B4',3;
exec RestockShelf 'Treadmill',24,'B0',3;
exec RestockShelf 'Trading Card Pack',7,'C2',3;
exec RestockShelf 'Video Game',23,'C4',2;
exec RestockShelf 'Armband',15,'A2',3;
exec RestockShelf 'Book',5,'C2',2;
exec RestockShelf 'Socks',10,'B0',1;
exec RestockShelf 'Trading Card Pack',17,'C2',3;
exec RestockShelf 'Smart Watch',9,'A2',1;
exec RestockShelf 'Notebook',11,'C1',1;
exec RestockShelf 'Video Game',23,'C4',2;
exec RestockShelf 'Stapler',20,'A1',3;
exec RestockShelf 'Granola Bar',15,'B2',1;
exec RestockShelf 'Book',24,'C2',2;
exec RestockShelf 'Fan',9,'C4',1;
exec RestockShelf 'Pull Up Bar',9,'A3',3;
exec RestockShelf 'Treadmill',15,'B0',3;
exec RestockShelf 'Video Game',24,'C4',2;
exec RestockShelf 'Granola Bar',10,'B2',1;
exec RestockShelf 'Camera',18,'C1',2;
exec RestockShelf 'Light Bulb',15,'A1',2;
exec RestockShelf 'Doorknob',5,'B3',3;
exec RestockShelf 'Apple',18,'A0',1;
exec RestockShelf 'Toothpaste',11,'B3',1;
exec RestockShelf 'Light Bulb',5,'A1',2;
exec RestockShelf 'Micromave',8,'C0',1;
exec RestockShelf 'Frame',24,'B2',3;
exec RestockShelf 'Suit Case',8,'B3',2;
exec RestockShelf 'Pizza',24,'A3',2;
exec RestockShelf 'Tape',5,'A0',3;
exec RestockShelf 'Video Game',6,'C4',2;
exec RestockShelf 'Hammer',9,'C0',3;
exec RestockShelf 'Smart Watch',21,'A2',1;
exec RestockShelf 'Screw',17,'B4',3;
exec RestockShelf 'Pull Up Bar',16,'A3',3;
exec RestockShelf 'Trading Card Pack',23,'C2',3;
exec RestockShelf 'Doorknob',23,'B3',3;
exec RestockShelf 'Scissors',24,'C3',1;
exec RestockShelf 'Spoon',7,'B4',1;
exec RestockShelf 'Suit Case',5,'B3',2;
exec RestockShelf 'Spoon',23,'B4',1;
exec RestockShelf 'Tape',14,'A0',3;
exec RestockShelf 'Broccoli',23,'B2',2;
exec RestockShelf 'Baseball',23,'C2',1;
exec RestockShelf 'Pizza',23,'A3',2;
exec RestockShelf 'Screw',20,'B4',3;
exec RestockShelf 'Laptop',9,'A3',1;
exec RestockShelf 'Orange',21,'A1',1;
exec RestockShelf 'Treadmill',23,'B0',3;
exec RestockShelf 'Toothpaste',14,'B3',1;
exec RestockShelf 'Camera',22,'C1',2;
exec RestockShelf 'Screw',21,'B4',3;
exec RestockShelf 'Ice Cream',24,'B0',2;
exec RestockShelf 'Athletic Tape',6,'C4',3;
exec RestockShelf 'Micromave',17,'C0',1;
exec RestockShelf 'Pool Noodle',14,'C0',2;
exec RestockShelf 'Pull Up Bar',11,'A3',3;
exec RestockShelf 'Laptop',14,'A3',1;
exec RestockShelf 'Shirt',12,'B1',1;
exec RestockShelf 'Scissors',19,'C3',1;
exec RestockShelf 'Armband',9,'A2',3;
exec RestockShelf 'Camping Tent',19,'A4',1;
exec RestockShelf 'Pull Up Bar',11,'A3',3;
exec RestockShelf 'Carrot',5,'B1',2;
exec RestockShelf 'Ice Cream',10,'B0',2;
exec RestockShelf 'Broccoli',22,'B2',2;
exec RestockShelf 'Trading Card Pack',18,'C2',3;
exec RestockShelf 'Scissors',9,'C3',1;
exec RestockShelf 'Doorknob',13,'B3',3;
exec RestockShelf 'Frame',7,'B2',3;
exec RestockShelf 'Toothpaste',16,'B3',1;
exec RestockShelf 'Cupcake',5,'A4',2;
exec RestockShelf 'Wall Hook',18,'C1',3;
exec RestockShelf 'Orange',7,'A1',1;
exec RestockShelf 'Socks',20,'B0',1;
exec RestockShelf 'Cupcake',17,'A4',2;
exec RestockShelf 'Notebook',5,'C1',1;
exec RestockShelf 'Suit Case',5,'B3',2;
exec RestockShelf 'Armband',24,'A2',3;
exec RestockShelf 'Micromave',20,'C0',1;
exec RestockShelf 'Shirt',20,'B1',1;
exec RestockShelf 'Wall Hook',13,'C1',3;
exec RestockShelf 'Baseball',9,'C2',1;
exec RestockShelf 'Broccoli',12,'B2',2;
exec RestockShelf 'Ice Cream',15,'B0',2;
exec RestockShelf 'Shirt',6,'B1',1;
exec RestockShelf 'Apple',21,'A0',1;
exec RestockShelf 'Frame',22,'B2',3;
exec RestockShelf 'Armband',16,'A2',3;
exec RestockShelf 'Carrot',23,'B1',2;
exec RestockShelf 'Tape',19,'A0',3;
exec RestockShelf 'Stapler',15,'A1',3;
exec RestockShelf 'Doorknob',5,'B3',3;
exec RestockShelf 'Scissors',23,'C3',1;
exec RestockShelf 'Pull Up Bar',8,'A3',3;
exec RestockShelf 'Cupcake',10,'A4',2;
exec RestockShelf 'Spoon',9,'B4',1;
exec RestockShelf 'Pool Noodle',20,'C0',2;
exec RestockShelf 'Light Bulb',15,'A1',2;
exec RestockShelf 'Multivitamin',8,'C3',3;
exec RestockShelf 'Stapler',11,'A1',3;
exec RestockShelf 'Wall Hook',17,'C1',3;
exec RestockShelf 'Spoon',19,'B4',1;
exec RestockShelf 'Doorknob',17,'B3',3;
exec RestockShelf 'Ice Cream',13,'B0',2;
exec RestockShelf 'Toothpaste',14,'B3',1;
exec RestockShelf 'Apple',22,'A0',1;
exec RestockShelf 'Treadmill',8,'B0',3;
exec RestockShelf 'Broccoli',15,'B2',2;
exec RestockShelf 'Apple',18,'A0',1;
exec RestockShelf 'Stapler',14,'A1',3;
exec RestockShelf 'Light Bulb',16,'A1',2;
exec RestockShelf 'Lawn Chair',6,'C3',2;
exec RestockShelf 'Bench',12,'A4',3;
exec RestockShelf 'Lamp',20,'A0',2;
exec RestockShelf 'Umbrella',10,'B4',2;
exec RestockShelf 'Orange',7,'A1',1;
exec RestockShelf 'Spoon',15,'B4',1;
exec RestockShelf 'Umbrella',22,'B4',2;
exec RestockShelf 'Athletic Tape',23,'C4',3;
exec RestockShelf 'Socks',13,'B0',1;
exec RestockShelf 'Umbrella',12,'B4',2;
exec RestockShelf 'Shirt',12,'B1',1;
exec RestockShelf 'Toothpaste',9,'B3',1;
exec RestockShelf 'Tape',19,'A0',3;
exec RestockShelf 'Notebook',10,'C1',1;
exec RestockShelf 'Shirt',19,'B1',1;
exec RestockShelf 'Umbrella',14,'B4',2;
exec RestockShelf 'Tape',12,'A0',3;
exec RestockShelf 'Multivitamin',10,'C3',3;
exec RestockShelf 'Ice Cream',19,'B0',2;
exec RestockShelf 'Video Game',15,'C4',2;
exec RestockShelf 'Cupcake',7,'A4',2;
exec RestockShelf 'Camera',9,'C1',2;
exec RestockShelf 'Armband',19,'A2',3;
exec RestockShelf 'Jacket',6,'A2',2;
exec RestockShelf 'Spoon',8,'B4',1;
exec RestockShelf 'Laptop',9,'A3',1;
exec RestockShelf 'Screw',23,'B4',3;
exec RestockShelf 'Orange',15,'A1',1;
exec RestockShelf 'Book',17,'C2',2;
exec RestockShelf 'Wall Hook',21,'C1',3;
exec RestockShelf 'Notebook',14,'C1',1;
exec RestockShelf 'Camping Tent',18,'A4',1;
exec RestockShelf 'Treadmill',16,'B0',3;
exec RestockShelf 'Stapler',6,'A1',3;
exec RestockShelf 'Wall Hook',21,'C1',3;
exec RestockShelf 'Stapler',13,'A1',3;
exec RestockShelf 'Micromave',10,'C0',1;
exec RestockShelf 'Smart Watch',8,'A2',1;
exec RestockShelf 'Pizza',24,'A3',2;
exec RestockShelf 'Carrot',11,'B1',2;
exec RestockShelf 'Broccoli',23,'B2',2;
exec RestockShelf 'Treadmill',11,'B0',3;
exec RestockShelf 'Camping Tent',20,'A4',1;
exec RestockShelf 'Frame',16,'B2',3;
exec RestockShelf 'Umbrella',5,'B4',2;
exec RestockShelf 'Book',10,'C2',2;
exec RestockShelf 'Pull Up Bar',21,'A3',3;
exec RestockShelf 'Athletic Tape',17,'C4',3;
exec RestockShelf 'Bench',8,'A4',3;
exec RestockShelf 'Smart Watch',18,'A2',1;
exec RestockShelf 'Suit Case',24,'B3',2;
exec RestockShelf 'Micromave',9,'C0',1;
exec RestockShelf 'Lawn Chair',18,'C3',2;
exec RestockShelf 'Lawn Chair',13,'C3',2;
exec RestockShelf 'Lamp',22,'A0',2;
exec RestockShelf 'Lawn Chair',14,'C3',2;
exec RestockShelf 'Lawn Chair',20,'C3',2;
exec RestockShelf 'Multivitamin',16,'C3',3;
exec RestockShelf 'Multivitamin',20,'C3',3;
exec RestockShelf 'Laptop',6,'A3',1;
exec RestockShelf 'Granola Bar',8,'B2',1;
exec RestockShelf 'Video Game',13,'C4',2;
exec RestockShelf 'Lamp',11,'A0',2;
exec RestockShelf 'Light Bulb',18,'A1',2;
exec RestockShelf 'Multivitamin',14,'C3',3;
exec RestockShelf 'Tape',21,'A0',3;
exec RestockShelf 'Bench',7,'A4',3;
exec RestockShelf 'Suit Case',23,'B3',2;
exec RestockShelf 'Hammer',23,'C0',3;
exec RestockShelf 'Notebook',23,'C1',1;
exec RestockShelf 'Tape',16,'A0',3;
exec RestockShelf 'Video Game',9,'C4',2;
exec RestockShelf 'Smart Watch',23,'A2',1;
exec RestockShelf 'Armband',9,'A2',3;
exec RestockShelf 'Carrot',10,'B1',2;
exec RestockShelf 'Camping Tent',19,'A4',1;
exec RestockShelf 'Scissors',22,'C3',1;
exec RestockShelf 'Cupcake',17,'A4',2;
exec RestockShelf 'Laptop',9,'A3',1;
exec RestockShelf 'Umbrella',13,'B4',2;
exec RestockShelf 'Book',19,'C2',2;
exec RestockShelf 'Umbrella',21,'B4',2;
exec RestockShelf 'Notebook',13,'C1',1;
exec RestockShelf 'Lamp',17,'A0',2;
exec RestockShelf 'Apple',6,'A0',1;
exec RestockShelf 'Light Bulb',13,'A1',2;
exec RestockShelf 'Tape',10,'A0',3;
exec RestockShelf 'Notebook',5,'C1',1;
exec RestockShelf 'Lawn Chair',24,'C3',2;
exec RestockShelf 'Baseball',21,'C2',1;
exec RestockShelf 'Doorknob',22,'B3',3;
exec RestockShelf 'Frame',7,'B2',3;
exec RestockShelf 'Wall Hook',17,'C1',3;
exec RestockShelf 'Hammer',11,'C0',3;
exec RestockShelf 'Baseball',7,'C2',1;
exec RestockShelf 'Fan',14,'C4',1;
exec RestockShelf 'Fan',9,'C4',1;
exec RestockShelf 'Frame',11,'B2',3;
exec RestockShelf 'Orange',8,'A1',1;
exec RestockShelf 'Doorknob',24,'B3',3;
exec RestockShelf 'Apple',8,'A0',1;
exec RestockShelf 'Broccoli',11,'B2',2;
exec RestockShelf 'Doorknob',8,'B3',3;
exec RestockShelf 'Laptop',18,'A3',1;
exec RestockShelf 'Carrot',15,'B1',2;
exec RestockShelf 'Cupcake',6,'A4',2;
exec RestockShelf 'Suit Case',21,'B3',2;
exec RestockShelf 'Book',17,'C2',2;
exec RestockShelf 'Suit Case',11,'B3',2;
exec RestockShelf 'Armband',21,'A2',3;
exec RestockShelf 'Apple',11,'A0',1;
exec RestockShelf 'Granola Bar',11,'B2',1;
exec RestockShelf 'Carrot',12,'B1',2;
exec RestockShelf 'Umbrella',13,'B4',2;
exec RestockShelf 'Laptop',14,'A3',1;
exec RestockShelf 'Bench',9,'A4',3;
exec RestockShelf 'Treadmill',12,'B0',3;
exec RestockShelf 'Baseball',16,'C2',1;
exec RestockShelf 'Scissors',14,'C3',1;
exec RestockShelf 'Baseball',18,'C2',1;
exec RestockShelf 'Stapler',13,'A1',3;
exec RestockShelf 'Pizza',12,'A3',2;
exec RestockShelf 'Stapler',23,'A1',3;
exec RestockShelf 'Picture',11,'B1',3;
exec RestockShelf 'Granola Bar',12,'B2',1;
exec RestockShelf 'Pool Noodle',23,'C0',2;
exec RestockShelf 'Smart Watch',12,'A2',1;
exec RestockShelf 'Pull Up Bar',22,'A3',3;
exec RestockShelf 'Athletic Tape',24,'C4',3;
exec RestockShelf 'Multivitamin',6,'C3',3;
exec RestockShelf 'Pizza',10,'A3',2;
exec RestockShelf 'Doorknob',14,'B3',3;
exec RestockShelf 'Tape',22,'A0',3;
exec RestockShelf 'Socks',11,'B0',1;
exec RestockShelf 'Scissors',23,'C3',1;
exec RestockShelf 'Trading Card Pack',6,'C2',3;
exec RestockShelf 'Athletic Tape',11,'C4',3;
exec RestockShelf 'Jacket',20,'A2',2;
exec RestockShelf 'Smart Watch',10,'A2',1;
exec RestockShelf 'Hammer',10,'C0',3;
exec RestockShelf 'Umbrella',10,'B4',2;
exec RestockShelf 'Camping Tent',7,'A4',1;
exec RestockShelf 'Bench',22,'A4',3;
exec RestockShelf 'Picture',13,'B1',3;
exec RestockShelf 'Hammer',20,'C0',3;
exec RestockShelf 'Baseball',12,'C2',1;
exec RestockShelf 'Bench',6,'A4',3;
exec RestockShelf 'Trading Card Pack',9,'C2',3;
exec RestockShelf 'Video Game',6,'C4',2;
exec RestockShelf 'Apple',15,'A0',1;
exec RestockShelf 'Fan',7,'C4',1;
exec RestockShelf 'Athletic Tape',6,'C4',3;
exec RestockShelf 'Camera',20,'C1',2;
exec RestockShelf 'Trading Card Pack',11,'C2',3;
exec RestockShelf 'Lamp',17,'A0',2;
exec RestockShelf 'Doorknob',12,'B3',3;
exec RestockShelf 'Camera',17,'C1',2;
exec RestockShelf 'Smart Watch',18,'A2',1;
exec RestockShelf 'Laptop',8,'A3',1;
exec RestockShelf 'Screw',5,'B4',3;
exec RestockShelf 'Athletic Tape',5,'C4',3;
exec RestockShelf 'Socks',5,'B0',1;
exec RestockShelf 'Pull Up Bar',16,'A3',3;
exec RestockShelf 'Cupcake',19,'A4',2;
exec RestockShelf 'Frame',10,'B2',3;
exec RestockShelf 'Toothpaste',22,'B3',1;
exec RestockShelf 'Carrot',5,'B1',2;
exec RestockShelf 'Micromave',24,'C0',1;
exec RestockShelf 'Camping Tent',7,'A4',1;
exec RestockShelf 'Camping Tent',18,'A4',1;
exec RestockShelf 'Lamp',7,'A0',2;
exec RestockShelf 'Screw',7,'B4',3;
exec RestockShelf 'Socks',18,'B0',1;
exec RestockShelf 'Shirt',22,'B1',1;
exec RestockShelf 'Athletic Tape',8,'C4',3;
exec RestockShelf 'Orange',12,'A1',1;
exec RestockShelf 'Ice Cream',18,'B0',2;
exec RestockShelf 'Broccoli',5,'B2',2;
exec RestockShelf 'Toothpaste',17,'B3',1;
exec RestockShelf 'Bench',24,'A4',3;
exec RestockShelf 'Picture',6,'B1',3;
exec RestockShelf 'Granola Bar',17,'B2',1;
exec RestockShelf 'Carrot',10,'B1',2;
exec RestockShelf 'Notebook',10,'C1',1;
exec RestockShelf 'Picture',13,'B1',3;
exec RestockShelf 'Bench',14,'A4',3;
exec RestockShelf 'Ice Cream',11,'B0',2;
exec RestockShelf 'Smart Watch',20,'A2',1;
exec RestockShelf 'Treadmill',24,'B0',3;
exec RestockShelf 'Notebook',16,'C1',1;
exec RestockShelf 'Laptop',14,'A3',1;
exec RestockShelf 'Screw',11,'B4',3;
exec RestockShelf 'Fan',23,'C4',1;
exec RestockShelf 'Socks',22,'B0',1;
exec RestockShelf 'Baseball',14,'C2',1;
exec RestockShelf 'Fan',18,'C4',1;
exec RestockShelf 'Jacket',8,'A2',2;
exec RestockShelf 'Lamp',14,'A0',2;
exec RestockShelf 'Pizza',10,'A3',2;
exec RestockShelf 'Pool Noodle',18,'C0',2;
exec RestockShelf 'Shirt',22,'B1',1;
exec RestockShelf 'Jacket',23,'A2',2;
exec RestockShelf 'Wall Hook',17,'C1',3;
exec RestockShelf 'Shirt',6,'B1',1;
exec RestockShelf 'Book',19,'C2',2;
exec RestockShelf 'Picture',8,'B1',3;
exec RestockShelf 'Pizza',9,'A3',2;
exec RestockShelf 'Scissors',14,'C3',1;
exec RestockShelf 'Light Bulb',22,'A1',2;
exec RestockShelf 'Carrot',20,'B1',2;
exec RestockShelf 'Fan',13,'C4',1;
exec RestockShelf 'Umbrella',12,'B4',2;
exec RestockShelf 'Suit Case',12,'B3',2;
exec RestockShelf 'Picture',22,'B1',3;
exec RestockShelf 'Pool Noodle',13,'C0',2;
exec RestockShelf 'Pool Noodle',24,'C0',2;
exec RestockShelf 'Hammer',11,'C0',3;
exec RestockShelf 'Pizza',24,'A3',2;
exec RestockShelf 'Micromave',7,'C0',1;
exec RestockShelf 'Jacket',9,'A2',2;
exec RestockShelf 'Armband',13,'A2',3;
exec RestockShelf 'Broccoli',24,'B2',2;
exec RestockShelf 'Notebook',22,'C1',1;
exec RestockShelf 'Picture',19,'B1',3;
exec RestockShelf 'Suit Case',12,'B3',2;
exec RestockShelf 'Lamp',13,'A0',2;
exec RestockShelf 'Pool Noodle',16,'C0',2;
exec RestockShelf 'Jacket',22,'A2',2;
exec RestockShelf 'Picture',6,'B1',3;
exec RestockShelf 'Hammer',21,'C0',3;
exec RestockShelf 'Lawn Chair',18,'C3',2;
exec RestockShelf 'Camping Tent',11,'A4',1;
exec RestockShelf 'Pull Up Bar',22,'A3',3;
exec RestockShelf 'Suit Case',18,'B3',2;
exec RestockShelf 'Laptop',24,'A3',1;
exec RestockShelf 'Tape',13,'A0',3;
exec RestockShelf 'Orange',22,'A1',1;
exec RestockShelf 'Picture',17,'B1',3;
exec RestockShelf 'Socks',11,'B0',1;
exec RestockShelf 'Granola Bar',13,'B2',1;
exec RestockShelf 'Trading Card Pack',8,'C2',3;
exec RestockShelf 'Broccoli',19,'B2',2;
exec RestockShelf 'Shirt',18,'B1',1;
exec RestockShelf 'Toothpaste',23,'B3',1;
exec RestockShelf 'Broccoli',16,'B2',2;
exec RestockShelf 'Pool Noodle',11,'C0',2;
exec RestockShelf 'Fan',8,'C4',1;
exec RestockShelf 'Orange',7,'A1',1;
exec RestockShelf 'Pool Noodle',5,'C0',2;
exec RestockShelf 'Apple',13,'A0',1;
exec RestockShelf 'Ice Cream',22,'B0',2;
exec RestockShelf 'Cupcake',10,'A4',2;
exec RestockShelf 'Spoon',7,'B4',1;
exec RestockShelf 'Lamp',24,'A0',2;
exec RestockShelf 'Light Bulb',14,'A1',2;
exec RestockShelf 'Multivitamin',13,'C3',3;
exec RestockShelf 'Lawn Chair',22,'C3',2;
exec RestockShelf 'Picture',9,'B1',3;
exec RestockShelf 'Screw',21,'B4',3;
exec RestockShelf 'Jacket',10,'A2',2;
exec RestockShelf 'Book',10,'C2',2;
exec RestockShelf 'Scissors',12,'C3',1;
exec RestockShelf 'Wall Hook',23,'C1',3;
exec RestockShelf 'Toothpaste',20,'B3',1;
exec RestockShelf 'Granola Bar',24,'B2',1;
exec RestockShelf 'Lawn Chair',17,'C3',2;
exec RestockShelf 'Shirt',11,'B1',1;
exec RestockShelf 'Lamp',24,'A0',2;
exec RestockShelf 'Armband',7,'A2',3;
exec RestockShelf 'Smart Watch',12,'A2',1;
exec RestockShelf 'Video Game',12,'C4',2;
exec RestockShelf 'Light Bulb',15,'A1',2;
exec RestockShelf 'Camping Tent',15,'A4',1;
exec RestockShelf 'Micromave',9,'C0',1;
exec RestockShelf 'Hammer',5,'C0',3;
exec RestockShelf 'Stapler',5,'A1',3;
exec RestockShelf 'Granola Bar',11,'B2',1;
exec RestockShelf 'Carrot',8,'B1',2;
exec RestockShelf 'Camping Tent',19,'A4',1;
exec RestockShelf 'Treadmill',5,'B0',3;
exec RestockShelf 'Camera',23,'C1',2;
exec RestockShelf 'Multivitamin',21,'C3',3;
exec RestockShelf 'Scissors',16,'C3',1;
exec RestockShelf 'Cupcake',19,'A4',2;
exec RestockShelf 'Lawn Chair',12,'C3',2;
exec RestockShelf 'Pool Noodle',20,'C0',2;
exec RestockShelf 'Socks',15,'B0',1;
exec RestockShelf 'Orange',11,'A1',1;
exec RestockShelf 'Bench',15,'A4',3;
go

-- Generate Purchases
declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8901','A';
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8902','A';
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8903','A';
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8904','A';
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8905','A';
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8906','A';
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8907','A';
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8908','A';
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8901','M';
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8902','M';
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8903','M';
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8904','M';
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8905','M';
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8906','M';
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8907','M';
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8908','M';
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8901','A';
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8902','A';
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8903','A';
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8904','A';
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8905','A';
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8906','A';
exec ScanItem 'Book',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8907','A';
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8908','A';
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8901','M';
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8902','M';
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8903','M';
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8904','M';
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8905','M';
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8906','M';
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8907','M';
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8908','M';
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8901','A';
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8902','A';
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8903','A';
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8904','A';
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8905','A';
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8906','A';
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8907','A';
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8908','A';
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8901','M';
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8902','M';
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8903','M';
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8904','M';
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8905','M';
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8906','M';
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8907','M';
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Book',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8908','M';
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8901','A';
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8902','A';
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Ice Cream',@StorePurchaseID;
exec ScanItem 'Armband',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8903','A';
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8904','A';
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Broccoli',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8905','A';
exec ScanItem 'Picture',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Pizza',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8906','A';
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8907','A';
exec ScanItem 'Laptop',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8908','A';
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Pool Noodle',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Baseball',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8901','M';
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Socks',@StorePurchaseID;
exec ScanItem 'Stapler',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8902','M';
exec ScanItem 'Pizza',@StorePurchaseID;
exec ScanItem 'Smart Watch',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Granola Bar',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Camera',@StorePurchaseID;
exec ScanItem 'Orange',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Tape',@StorePurchaseID;
exec ScanItem 'Laptop',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8903','M';
exec ScanItem 'Micromave',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Spoon',@StorePurchaseID;
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Notebook',@StorePurchaseID;
exec ScanItem 'Fan',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Camping Tent',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec ScanItem 'Trading Card Pack',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8904','M';
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec ScanItem 'Umbrella',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Video Game',@StorePurchaseID;
exec ScanItem 'Treadmill',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Toothpaste',@StorePurchaseID;
exec ScanItem 'Pull Up Bar',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Cupcake',@StorePurchaseID;
exec ScanItem 'Wall Hook',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8905','M';
exec ScanItem 'Athletic Tape',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec ScanItem 'Carrot',@StorePurchaseID;
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Screw',@StorePurchaseID;
exec ScanItem 'Suit Case',@StorePurchaseID;
exec ScanItem 'Scissors',@StorePurchaseID;
exec ScanItem 'Light Bulb',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8906','M';
exec ScanItem 'Shirt',@StorePurchaseID;
exec ScanItem 'Jacket',@StorePurchaseID;
exec ScanItem 'Lamp',@StorePurchaseID;
exec ScanItem 'Doorknob',@StorePurchaseID;
exec ScanItem 'Micromave',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8907','M';
exec ScanItem 'Lawn Chair',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go

declare @StorePurchaseID int
exec @StorePurchaseID = InitializePurchase '234-567-8908','M';
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Bench',@StorePurchaseID;
exec ScanItem 'Hammer',@StorePurchaseID;
exec ScanItem 'Frame',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Multivitamin',@StorePurchaseID;
exec ScanItem 'Apple',@StorePurchaseID;
exec FinalizePurchase @StorePurchaseID;
go


-- Artificially manipulate Restock dates for the purposes of this project
update ShelfRestock set Date = DATEADD(WEEK, -3, Date)
go
update ShelfRestock set Date = DATEADD(WEEK, -3, Date) where RestockID > 45
go
update ShelfRestock set Date = DATEADD(WEEK, -3, Date) where RestockID > 90
go
update ShelfRestock set Date = DATEADD(WEEK, -3, Date) where RestockID > 135
go
update ShelfRestock set Date = DATEADD(WEEK, -3, Date) where RestockID > 180
go
update ShelfRestock set Date = DATEADD(WEEK, -3, Date) where RestockID > 225
go
update ShelfRestock set Date = DATEADD(WEEK, -3, Date) where RestockID > 270
go
update ShelfRestock set Date = DATEADD(WEEK, -3, Date) where RestockID > 315
go
update ShelfRestock set Date = DATEADD(WEEK, -3, Date) where RestockID > 360
go
update ShelfRestock set Date = DATEADD(WEEK, -3, Date) where RestockID > 405
go

-- Artificially manipulate Inventory Order dates for the purposes of this project
update InventoryOrder set Date = DATEADD(WEEK, -3, Date)
go
update InventoryOrder set Date = DATEADD(WEEK, -3, Date) where OrderID > 45
go
update InventoryOrder set Date = DATEADD(WEEK, -3, Date) where OrderID > 90
go
update InventoryOrder set Date = DATEADD(WEEK, -3, Date) where OrderID > 135
go
update InventoryOrder set Date = DATEADD(WEEK, -3, Date) where OrderID > 180
go
update InventoryOrder set Date = DATEADD(WEEK, -3, Date) where OrderID > 225
go
update InventoryOrder set Date = DATEADD(WEEK, -3, Date) where OrderID > 270
go
update InventoryOrder set Date = DATEADD(WEEK, -3, Date) where OrderID > 315
go
update InventoryOrder set Date = DATEADD(WEEK, -3, Date) where OrderID > 360
go
update InventoryOrder set Date = DATEADD(WEEK, -3, Date) where OrderID > 405
go

-- Artificially manipulate Purchase dates for the purposes of this project
update Purchase set StartTime = DATEADD(WEEK, -3, StartTime), EndTime = DATEADD(WEEK, -3, EndTime)
go
update Purchase set StartTime = DATEADD(WEEK, -3, StartTime), EndTime = DATEADD(WEEK, -3, EndTime) where PurchaseID > 9
go
update Purchase set StartTime = DATEADD(WEEK, -3, StartTime), EndTime = DATEADD(WEEK, -3, EndTime) where PurchaseID > 18
go
update Purchase set StartTime = DATEADD(WEEK, -3, StartTime), EndTime = DATEADD(WEEK, -3, EndTime) where PurchaseID > 27
go
update Purchase set StartTime = DATEADD(WEEK, -3, StartTime), EndTime = DATEADD(WEEK, -3, EndTime) where PurchaseID > 36
go
update Purchase set StartTime = DATEADD(WEEK, -3, StartTime), EndTime = DATEADD(WEEK, -3, EndTime) where PurchaseID > 45
go
update Purchase set StartTime = DATEADD(WEEK, -3, StartTime), EndTime = DATEADD(WEEK, -3, EndTime) where PurchaseID > 54
go

-- Artificially increase the EndTime for Purchases for purposes of this project
update Purchase set EndTime = DATEADD(MINUTE, 3, EndTime) where PurchaseID in
(select PurchaseID from Basket b group by PurchaseID having count(Quantity) > 3)
go
update Purchase set EndTime = DATEADD(MINUTE, 4, EndTime) where PurchaseID in
(select PurchaseID from Basket b group by PurchaseID having count(Quantity) > 6)
go
update Purchase set EndTime = DATEADD(MINUTE, 2, EndTime) where PurchaseID in
(select PurchaseID from Basket b group by PurchaseID having count(Quantity) > 9)
go
update Purchase set EndTime = DATEADD(MINUTE, 6, EndTime) where PurchaseID in
(select PurchaseID from Basket b group by PurchaseID having count(Quantity) > 14)
go
update Purchase set EndTime = DATEADD(MINUTE, 5, EndTime) where PurchaseID in
(select PurchaseID from Basket b group by PurchaseID having count(Quantity) > 19)
go
update Purchase set EndTime = DATEADD(MINUTE, 7, EndTime) where PurchaseID in
(select PurchaseID from Basket b group by PurchaseID having count(Quantity) > 22)
go
update Purchase set EndTime = DATEADD(MINUTE, 3, EndTime) where PurchaseID in
(select PurchaseID from Basket b group by PurchaseID having count(Quantity) > 25)
go
update Purchase set EndTime = DATEADD(MINUTE, 8, EndTime) where PurchaseID in
(select PurchaseID from Basket b group by PurchaseID having count(Quantity) > 30)
go

/* IF VIEWS EXIST, DROP THEM */
IF OBJECT_ID('dbo.ItemsPerPurchase') IS NOT NULL
BEGIN
drop view dbo.ItemsPerPurchase
END
go

--Create view that shows number of items per transaction
create view ItemsPerPurchase as
	select PurchaseID, sum(Quantity) as TotalQuantity from Basket group by PurchaseID
go