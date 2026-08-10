namespace RealWorldApi.Dtos;

public class OrderResponse
{
    public Guid Id { get; set; }
    public string CustomerName { get; set; } = "";
    public string ProductCode { get; set; } = "";
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal Total { get; set; }
    public DateTime CreatedUtc { get; set; }
}