import numpy as np

class GrayCoder:
    """
    Utility class for Gray code conversion and inverse conversion.
    
    Attributes:
        bits (int): Number of bits required for QAM size.
        mask (int): Bit mask to restrict values to valid range.
    """
    def __init__(self, qam_size):
        """
        Initialize GrayCoder with QAM size.
        
        Args:
            qam_size (int): QAM constellation size (e.g., 16, 64, 128, 256).
        
        Raises:
            ValueError: If qam_size is not a power of 2.
        """
        if not np.log2(qam_size).is_integer():
            raise ValueError("QAM size must be a power of 2")
        self.bits = int(np.log2(qam_size))
        self.mask = (1 << self.bits) - 1

    def to_gray(self, vals):
        """
        Convert binary indices to Gray code.
        
        Args:
            vals (np.ndarray or int): Binary indices.
        
        Returns:
            np.ndarray or int: Gray-coded values.
        """
        vals = np.array(vals) & self.mask
        return vals ^ (vals >> 1)

    def from_gray(self, vals):
        """
        Convert Gray-coded values to binary indices.
    
        Args:
            vals (np.ndarray or int): Gray-coded values.
    
        Returns:
            np.ndarray or int: Binary indices.
        """
        vals = np.array(vals) & self.mask
        b = vals 
        shift = 1
        while shift < self.bits:
            b ^= (b >> shift)  # ここをbにするのが正解
            shift <<= 1
        return b

def generate_constellation(qam_size):
    """
    Generate normalized QAM constellation points.

    Args:
        qam_size (int): QAM constellation size (16, 64, 128, or 256).

    Returns:
        np.ndarray: Complex constellation points normalized to unit average power.

    Raises:
        ValueError: If QAM size is not 16, 64, 128, or 256.
    """
    if qam_size not in [16, 64, 128, 256]:
        raise ValueError(f"Unsupported QAM size: {qam_size}")

    if qam_size == 128:
        # QAM-128: 8x16グリッド（I軸8点、Q軸16点）
        coords_i = np.arange(-7, 8, 2)  # 8 points for I-axis
        coords_q = np.arange(-15, 16, 2)  # 16 points for Q-axis
        I, Q = np.meshgrid(coords_i, coords_q)
        points = I.flatten() + 1j * Q.flatten()
    else:
        # QAM-16 (4x4), QAM-64 (8x8), QAM-256 (16x16)
        points_per_axis = int(np.sqrt(qam_size))
        coords = np.arange(-points_per_axis + 1, points_per_axis, 2)
        I, Q = np.meshgrid(coords, coords)
        points = I.flatten() + 1j * Q.flatten()

    avg_power = np.mean(np.abs(points)**2)
    norm_points = points / np.sqrt(avg_power, dtype=np.float64)
    return norm_points
