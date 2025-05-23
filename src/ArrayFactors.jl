"""
    ArrayFactors(af::Vector{<:AbstractArray}, di::DimIndices)
    ArrayFactors(af::Vector{<:AbstractArray}, di::Vector)
    ArrayFactors(af::Vector{<:AbstractArray})

Array factors are defined such that the array's elements are their products:
`M[i, j, ..., l] = af[1][i] * af[2][j] * ... * af[3][l]`.

The array factors can be vectors or multidimensional arrays themselves.

The main use of ArrayFactors is as a memory-efficient representation of a
multidimensional array, which can be constructed using the `Array()`
method.

see also: [`ipf`](@ref), [`ArrayMargins`](@ref), [`DimIndices`](@ref)

# Fields
- `af::Vector{<:AbstractArray}`: Vector of (multidimensional) array factors
- `di::DimIndices`: Dimension indices to which the array factors belong.

# Examples
```julia-repl
julia> AF = ArrayFactors([[1,2,3], [4,5]])
Factors for array of size (3, 2):
  [1]: [1, 2, 3]
  [2]: [4, 5]

julia> eltype(AF)
Int64

julia> Array(AF)
3×2 Matrix{Int64}:
  4   5
  8  10
 12  15

julia> AF = ArrayFactors([[1,2,3], [4 5; 6 7]], DimIndices([2, [1, 3]]))
Factors for 3D array:
  [2]: [1, 2, 3]
  [1, 3]: [4 5; 6 7]

julia> Array(AF)
2×3×2 Array{Int64, 3}:
[:, :, 1] =
 4   8  12
 6  12  18

[:, :, 2] =
 5  10  15
 7  14  21
```
"""
struct ArrayFactors{T}
    af::Vector{<:AbstractArray{T}}
    di::DimIndices
    size::Tuple

    function ArrayFactors(af::Vector{<:AbstractArray{T}}, di::DimIndices) where {T}
        # loop over arrays then dimensions to get size, checking for mismatches
        dimension_sizes = zeros(Int, ndims(di))
        for i in 1:length(af)
            for (j, d) in enumerate(di.idx[i])
                new_size = size(af[i], j)
                if dimension_sizes[d] == 0
                    dimension_sizes[d] = new_size
                    continue
                end
                # check
                if dimension_sizes[d] != new_size
                    throw(
                        DimensionMismatch(
                            "Dimension sizes not equal for dimension $d: $(dimension_sizes[d]) and $new_size",
                        ),
                    )
                end
            end
        end
        return new{T}(af, di, Tuple(dimension_sizes))
    end
end

# Constructor for mixed-type arrayfactors needs promotion before construction
function ArrayFactors(af::Vector{<:AbstractArray}, di::DimIndices)
    AT = eltype(af)
    PT = promote_type(eltype.(af)...)
    return ArrayFactors(Vector{AT{PT}}(af), di)
end

# Constructor promoting vector to dimindices
ArrayFactors(af::Vector{<:AbstractArray}, di::Vector) = ArrayFactors(af, DimIndices(di))

# Constructor based on factors without dimindices
ArrayFactors(af::Vector{<:AbstractArray}) = ArrayFactors(af, default_dimindices(af))

# Overloading base methods
function Base.eltype(::Type{ArrayFactors{T}}) where {T}
    return T
end

function Base.show(io::IO, AF::ArrayFactors)
    print(io, "Factors for $(ndims(AF.di))D array:")
    for i in 1:length(AF.af)
        print(io, "\n  $(AF.di.idx[i]): ")
        show(io, AF.af[i])
    end
end

Base.size(AF::ArrayFactors) = AF.size
Base.length(AF::ArrayFactors) = length(AF.af)

# method to align all arrays so each has dimindices 1:ndims(AM)
function align_margins(AF::ArrayFactors{T})::Vector{Array{T}} where T
    align_margins(AF.af, AF.di, AF.size)
end

"""
    Array(AF::ArrayFactors{T})

Create an array out of an ArrayFactors object.

# Arguments
- `A::ArrayFactors{T}`: Array factors

# Examples
```julia-repl
julia> fac = ArrayFactors([[1,2,3], [4,5], [6,7]])
Factors for array of size (3, 2, 2):
    1: [1, 2, 3]
    2: [4, 5]
    3: [6, 7]

julia> Array(fac)
3×2×2 Array{Int64, 3}:
[:, :, 1] =
 24  30
 48  60
 72  90

[:, :, 2] =
 28   35
 56   70
 84  105
```
"""
function Base.Array(AF::ArrayFactors{T}) where {T}
    D = length(AF.di)
    M = ones(T, size(AF))
    aligned_factors = align_margins(AF)
    for d in 1:D
        M .*= aligned_factors[d]
    end
    return M
end
