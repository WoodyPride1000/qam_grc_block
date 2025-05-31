import numpy as np

def generate_constellation(qam_size):
    """
    Generate normalized QAM constellation points.

    Args:
        qam_size (int): 64 or 128.

    Returns:
        np.ndarray: Complex constellation points normalized to unit average power.

    Raises:
        ValueError: Unsupported QAM size.
    """
    if qam_size == 64:
        points_per_axis = 8
    elif qam_size == 128:
        points_per_axis = 12
    else:
        raise ValueError(f"Unsupported QAM size: {qam_size}")

    coords = [2*x - points_per_axis + 1 for x in range(points_per_axis)]
    points = [complex(i, q) for i in coords for q in coords]

    if qam_size == 128:
        points.sort(key=lambda p: abs(p))
        points = points[:128]

    avg_power = np.mean([abs(p)**2 for p in points])
    norm_points = np.array(points) / np.sqrt(avg_power)
    return norm_points

def gray_map(val):
    """
    Convert binary index to Gray code.

    Args:
        val (int): Binary index.

    Returns:
        int: Gray code value.
    """
    return val ^ (val >> 1)
