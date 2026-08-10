namespace RealWorldApi.Dtos;

public class CreateOrderRequest
{
    public string CustomerName { get; set; } = "";
    public string ProductCode { get; set; } = "";
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
}