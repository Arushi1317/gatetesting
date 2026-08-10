using RealWorldApi.Models;

namespace RealWorldApi.Repositories;

public interface IOrderRepository
{
    Task<Order> AddAsync(Order order, CancellationToken ct = default);
    Task<Order?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<Order>> GetAllAsync(CancellationToken ct = default);
}