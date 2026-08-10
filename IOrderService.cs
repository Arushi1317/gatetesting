using RealWorldApi.Dtos;

namespace RealWorldApi.Services;

public interface IOrderService
{
    Task<OrderResponse> CreateAsync(CreateOrderRequest request, CancellationToken ct = default);
    Task<OrderResponse?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<OrderResponse>> GetAllAsync(CancellationToken ct = default);
}