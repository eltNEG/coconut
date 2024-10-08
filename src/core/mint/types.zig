const nuts = @import("../lib.zig").nuts;
const std = @import("std");
const amount_lib = @import("../lib.zig").amount;
const CurrencyUnit = @import("../lib.zig").nuts.CurrencyUnit;
const MintQuoteState = @import("../lib.zig").nuts.nut04.QuoteState;
const MeltQuoteState = @import("../lib.zig").nuts.nut05.QuoteState;
const secp256k1 = @import("secp256k1");
const zul = @import("zul");

/// Mint Quote Info
pub const MintQuote = struct {
    /// Quote id
    id: [16]u8,
    /// Mint Url
    mint_url: []const u8,
    /// Amount of quote
    amount: amount_lib.Amount,
    /// Unit of quote
    unit: CurrencyUnit,
    /// Quote payment request e.g. bolt11
    request: []const u8,
    /// Quote state
    state: MintQuoteState,
    /// Expiration time of quote
    expiry: u64,
    /// Value used by ln backend to look up state of request
    request_lookup_id: []const u8,

    /// formatting mint quote
    pub fn format(
        self: MintQuote,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("{}", .{std.json.fmt(self, .{})});
    }

    /// Create new [`MintQuote`]
    /// creating copy of arguments, so caller responsible on deinit resources
    pub fn initAlloc(
        allocator: std.mem.Allocator,
        mint_url: []const u8,
        request: []const u8,
        unit: CurrencyUnit,
        amount: amount_lib.Amount,
        expiry: u64,
        request_lookup_id: []const u8,
    ) !MintQuote {
        const id = zul.UUID.v4();

        const mint_quote: MintQuote = .{
            .mint_url = mint_url,
            .id = id.bin,
            .amount = amount,
            .unit = unit,
            .request = request,
            .state = .unpaid,
            .expiry = expiry,
            .request_lookup_id = request_lookup_id,
        };

        return try mint_quote.clone(allocator);
    }

    pub fn deinit(self: *const MintQuote, allocator: std.mem.Allocator) void {
        allocator.free(self.request_lookup_id);
        allocator.free(self.request);
    }

    pub fn clone(self: *const MintQuote, allocator: std.mem.Allocator) !MintQuote {
        const request_lookup = try allocator.dupe(u8, self.request_lookup_id);
        errdefer allocator.free(request_lookup);

        const request = try allocator.dupe(u8, self.request);
        errdefer allocator.free(request);

        const mint_url = try allocator.dupe(u8, self.mint_url);
        errdefer allocator.free(mint_url);

        var cloned = self.*;

        cloned.request = request;
        cloned.request_lookup_id = request_lookup;
        cloned.mint_url = mint_url;

        return cloned;
    }
};

/// Melt Quote Info
pub const MeltQuote = struct {
    /// Quote id
    id: [16]u8,
    /// Quote unit
    unit: CurrencyUnit,
    /// Quote amount
    amount: amount_lib.Amount,
    /// Quote Payment request e.g. bolt11
    request: []const u8,
    /// Quote fee reserve
    fee_reserve: amount_lib.Amount,
    /// Quote state
    state: MeltQuoteState,
    /// Expiration time of quote
    expiry: u64,
    /// Payment preimage
    payment_preimage: ?[]const u8,
    /// Value used by ln backend to look up state of request
    request_lookup_id: []const u8,

    /// Create new [`MeltQuote`]
    pub fn init(
        request: []const u8,
        unit: CurrencyUnit,
        amount: amount_lib.Amount,
        fee_reserve: amount_lib.Amount,
        expiry: u64,
        request_lookup_id: []const u8,
    ) MeltQuote {
        const id = zul.UUID.v4();

        return .{
            .id = id.bin,
            .amount = amount,
            .unit = unit,
            .request = request,
            .fee_reserve = fee_reserve,
            .state = .unpaid,
            .expiry = expiry,
            .payment_preimage = null,
            .request_lookup_id = request_lookup_id,
        };
    }

    pub fn deinit(self: *const MeltQuote, allocator: std.mem.Allocator) void {
        allocator.free(self.request);
        allocator.free(self.request_lookup_id);
        if (self.payment_preimage) |preimage| allocator.free(preimage);
    }

    pub fn clone(self: *const MeltQuote, allocator: std.mem.Allocator) !MeltQuote {
        var cloned = self.*;

        const request_lookup_id = try allocator.alloc(u8, self.request_lookup_id.len);
        errdefer allocator.free(cloned.request_lookup_id);

        @memcpy(request_lookup_id, self.request_lookup_id);

        const request = try allocator.alloc(u8, self.request.len);
        errdefer allocator.free(request);

        @memcpy(request, self.request);

        cloned.request_lookup_id = request_lookup_id;
        cloned.request = request;

        if (cloned.payment_preimage) |preimage| {
            const preimage_cloned = try allocator.alloc(u8, self.request.len);
            errdefer allocator.free(preimage_cloned);

            @memcpy(preimage_cloned, preimage);

            cloned.payment_preimage = preimage_cloned;
        }

        return cloned;
    }
};

pub const ProofInfo = struct {
    /// Proof
    proof: nuts.Proof,
    /// y
    y: secp256k1.PublicKey,
    /// Mint Url
    mint_url: []u8,
    /// Proof State
    state: nuts.nut07.State,
    /// Proof Spending Conditions
    spending_condition: ?nuts.nut11.SpendingConditions,
    /// Unit
    unit: nuts.CurrencyUnit,

    /// Create new [`ProofInfo`]
    pub fn init(
        proof: nuts.Proof,
        mint_url: []u8,
        state: nuts.nut07.State,
        unit: nuts.CurrencyUnit,
    ) ProofInfo {
        const secret = nuts.nut10.Secret.fromSecret(proof.secret);
        return .{
            .proof = proof,
            .y = proof.c,
            .mint_url = mint_url,
            .state = state,
            .spending_conditions = nuts.nut10.toSpendingConditions(secret) catch null,
            .unit = unit,
        };
    }
};
