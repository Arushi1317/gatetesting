using RealWorldApi.Dtos;
using RealWorldApi.Models;
using RealWorldApi.Repositories;

namespace RealWorldApi.Services;

public class OrderService : IOrderService
{
    private readonly IOrderRepository _repo;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository repo, ILogger<OrderService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public async Task<OrderResponse> CreateAsync(CreateOrderRequest request, CancellationToken ct = default)
    {
        Validate(request);

        // Intentional analyzable pattern for warnings in some setups:
        // variable that could be inline/simplified
        var normalizedProduct = request.ProductCode.Trim().ToUpperInvariant();

        var entity = new Order
        {
            CustomerName = request.CustomerName.Trim(),
            ProductCode = normalizedProduct,
            Quantity = request.Quantity,
            UnitPrice = request.UnitPrice
        };

        var saved = await _repo.AddAsync(entity, ct);
        _logger.LogInformation("Order {OrderId} created for {Customer}", saved.Id, saved.CustomerName);

        return Map(saved);
    }

    public async Task<IReadOnlyList<OrderResponse>> GetAllAsync(CancellationToken ct = default)
    {
        var data = await _repo.GetAllAsync(ct);
        return data.Select(Map).ToList();
    }

    public async Task<OrderResponse?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        var order = await _repo.GetByIdAsync(id, ct);
        return order is null ? null : Map(order);
    }

    private static void Validate(CreateOrderRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.CustomerName))
            throw new ArgumentException("CustomerName is required.");
        if (string.IsNullOrWhiteSpace(request.ProductCode))
            throw new ArgumentException("ProductCode is required.");
        if (request.Quantity <= 0)
            throw new ArgumentException("Quantity must be > 0.");
        if (request.UnitPrice <= 0)
            throw new ArgumentException("UnitPrice must be > 0.");
    }

    private static OrderResponse Map(Order x) => new()
    {
        Id = x.Id,
        CustomerName = x.CustomerName,
        ProductCode = x.ProductCode,
        Quantity = x.Quantity,
        UnitPrice = x.UnitPrice,
        Total = x.Total,
        CreatedUtc = x.CreatedUtc
    };
}