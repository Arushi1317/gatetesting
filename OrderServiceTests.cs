using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using RealWorldApi.Dtos;
using RealWorldApi.Repositories;
using RealWorldApi.Services;

namespace RealWorldApi.Tests;

public class OrderServiceTests
{
    [Fact]
    public async Task CreateAsync_ValidRequest_ReturnsCreatedOrder()
    {
        var repo = new InMemoryOrderRepository();
        var service = new OrderService(repo, NullLogger<OrderService>.Instance);

        var response = await service.CreateAsync(new CreateOrderRequest
        {
            CustomerName = "Alice",
            ProductCode = "prd-1",
            Quantity = 2,
            UnitPrice = 10
        });

        response.CustomerName.Should().Be("Alice");
        response.ProductCode.Should().Be("PRD-1");
        response.Total.Should().Be(20);
    }

    [Fact]
    public async Task CreateAsync_InvalidQuantity_Throws()
    {
        var repo = new InMemoryOrderRepository();
        var service = new OrderService(repo, NullLogger<OrderService>.Instance);

        var act = async () => await service.CreateAsync(new CreateOrderRequest
        {
            CustomerName = "Bob",
            ProductCode = "X",
            Quantity = 0,
            UnitPrice = 10
        });

        await act.Should().ThrowAsync<ArgumentException>()
            .WithMessage("*Quantity must be > 0*");
    }
}