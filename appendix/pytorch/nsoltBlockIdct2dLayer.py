import torch
import torch.nn as nn
import torch_dct as dct
import numpy as np 
from nsoltUtility import Direction

class NsoltBlockIdct2dLayer(nn.Module):
    """
    NSOLTBLOCKIDCT2DLAYER
    
       コンポーネント別に入力(nComponents):
          nSamples x nRows x nCols x nDecs
    
       ベクトル配列をブロック配列にして出力:
          nSamples x nComponents x (Stride(1)xnRows) x (Stride(2)xnCols) 
        
    Requirements: Python 3.7.x, PyTorch 1.7.x
    
    Copyright (c) 2020-2021, Shogo MURAMATSU
    
    All rights reserved.
    
    Contact address: Shogo MURAMATSU,
        Faculty of Engineering, Niigata University,
        8050 2-no-cho Ikarashi, Nishi-ku,
        Niigata, 950-2181, JAPAN
    
        http://msiplab.eng.niigata-u.ac.jp/
    """
    def __init__(self,
        name='',
        decimation_factor=[],
        number_of_components=1
        ):
        super(NsoltBlockIdct2dLayer, self).__init__()
        self.decimation_factor = decimation_factor 
        self.name = name 
        self.description = "Block IDCT of size " \
            + str(self.decimation_factor[Direction.VERTICAL]) + "x" \
            + str(self.decimation_factor[Direction.HORIZONTAL])
        #self.type = ''
        self.num_inputs = number_of_components

    def forward(self,x):
        block_size = self.decimation_factor
        nsamples = x.size(0)
        nrows = x.size(1)
        ncols = x.size(2)
        # Permute IDCT coefficients
        coefs = x.view(-1,np.prod(block_size))
        decY_ = block_size[Direction.VERTICAL]
        decX_ = block_size[Direction.HORIZONTAL]
        chDecY = np.ceil(decY_/2.).astype(int)
        chDecX = np.ceil(decX_/2.).astype(int)
        fhDecY = np.floor(decY_/2.).astype(int)
        fhDecX = np.floor(decX_/2.).astype(int)
        nQDecsee = chDecY*chDecX
        nQDecsoo = fhDecY*fhDecX
        nQDecsoe = fhDecY*chDecX
        cee = coefs[:,:nQDecsee]
        coo = coefs[:,nQDecsee:nQDecsee+nQDecsoo]
        coe = coefs[:,nQDecsee+nQDecsoo:nQDecsee+nQDecsoo+nQDecsoe]
        ceo = coefs[:,nQDecsee+nQDecsoo+nQDecsoe:]
        nBlocks = coefs.size(0)
        value = torch.zeros(nBlocks,decY_,decX_,dtype=x.dtype)
        value[:,0::2,0::2] = cee.view(nBlocks,chDecY,chDecX)
        value[:,1::2,1::2] = coo.view(nBlocks,fhDecY,fhDecX)
        value[:,1::2,0::2] = coe.view(nBlocks,fhDecY,chDecX)
        value[:,0::2,1::2] = ceo.view(nBlocks,chDecY,fhDecX)
        # 2D IDCT
        y = dct.idct_2d(value,norm='ortho')
        # Reshape and return
        height = nrows * decY_ 
        width = ncols * decX_
        return y.reshape(nsamples,1,height,width)