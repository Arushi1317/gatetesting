namespace RealWorldApi.Models;

public class Order
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string CustomerName { get; set; } = "";
    public string ProductCode { get; set; } = "";
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    public decimal Total => Quantity * UnitPrice;
}